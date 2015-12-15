---
layout: post
title: Integration testing on top of NancyFx and ngrok tunnel
date: 2015-12-15T23:00:01.000Z
summary: "Simple ideas on making hard staff really easy!"
categories: testing
published: true
---


Recently I've faced with pretty _interesting_ API for payment service [Platron](https://platron.ru). To make sure that integration scenario of simple one-time payment will work in production I had to implement sample http server which will receive callback with the result of client payment and will be publicly available to Platron server. 

Full scenario under the test looks like this:
* Client calls server and says he wants to pay let's say 5 RUB (it processess requests in rubles) for order №1
* Server calls Platron API where it specifies all parameters including amount of money to receive in so called `InitPayment` request. Platron returns redirect url to complete payment. Server returns that url to user (web client).
* Browser redirects client to that url. User processes payment using prefferred payment system. Platron accepts money transaction and sends request to special url(`ResultUrl`).
* Server specified in `ResultUrl` accepts request from Platron, authenticates it, and sends a valid signed response to complete payment by Platron (it can be _error_, _ok_, _reject_). I'm not interested in wasting company's money so I choose to _reject_ it :).

So there're two parts in equation: 
* http server to host simple callback server and modify it's behaviour according to scenario requirements,
* proxy server's endpoint or publish server to make it available externally. 

Actually there is a final part - to combine it all together, but it'll be a bit later.

[First one](https://github.com/sergiorykov/Platron.Client/tree/master/Source/Platron.Client.TestKit/Emulators/Nancy) - is as easy as creating first [NancyFx](http://nancyfx.org) module:
```csharp
public sealed class PlatronModule : NancyModule
{
    private readonly PlatronClient _platronClient;

    public PlatronModule(PlatronClient platronClient)
    {
        // IoC container will make us super-duper happy and gives us a client.
        _platronClient = platronClient;

        Get["/platron/result", true] = async (_, ct) =>
        {
            CallbackResponse response = await CompleteOrderAsync(Request.Url);
            return AsXml(response);
        };
    }

    private async Task<CallbackResponse> CompleteOrderAsync(Uri resultUrl)
    {
        ResultUrlRequest request = _platronClient.ResultUrl.Parse(resultUrl);
        CallbackResponse response = _platronClient.ResultUrl.ReturnOk(request, "Order completed");
        return await Task.FromResult(response);
    }

    private Response AsXml(CallbackResponse response)
    {
        return new Response
                {
                    ContentType = "application/xml; charset:utf-8",
                    Contents = stream =>
                    {
                        var data = Encoding.UTF8.GetBytes(response.Content);
                        stream.Write(data, 0, data.Length);
                    },
                    StatusCode = (HttpStatusCode) System.Net.HttpStatusCode.OK
                };
    }
}
``` 
Followed by default startup 
```csharp
public sealed class Startup
{
    public void Configuration(IAppBuilder app)
    {
          app.UseNancy();
    }
}
```
and integrating thru [Nancy.Owin](https://www.nuget.org/packages/Nancy.Owin) with OWIN host [Microsoft.Owin.Host.HttpListener](https://www.nuget.org/packages/Microsoft.Owin.Host.HttpListener).

Next question is how to make it available externally. It's direct job of tunnelling services like https://forwardhq.com, https://ngrok.com or any similar. [We have choosen ngrok](https://github.com/sergiorykov/Platron.Client/tree/master/Source/Platron.Client.TestKit/Emulators/Tunnels) - it has free of charge version tunnelling a single address. It has several little noisy drawbacks (for automation purposes only - it's really awesome service to know and have it in your toolbox): random third-level public domain name (like smth123rndm2.ngrok.com), with a [related question](https://github.com/sergiorykov/Platron.Client/issues/1) how to get it.

You will need to [download ngrok](https://ngrok.com/download) and make it available in PATH (including all compatible CI agent machines too!). Or you can write little script to install it on premise (like chocolate does). Everything else will  be done automagically by `CallbackServerEmulator`:
```csharp
public sealed class CallbackServerEmulator : IDisposable
{
    private IDisposable _app;
    private IDisposable _tunnel;

    public Uri LocalAddress { get; private set; }
    public Uri ExternalAddress { get; private set; }
    public int Port { get; private set; }

    public void Start()
    {
        var port = FreeTcpPort();
        Start(port);
    }

    public void Start(int port)
    {
        _app = WebApp.Start<Startup>($"http://+:{port}");

        // doesn't require license to run single instance with generated domain
        var ngrok = new NgrokTunnel(port, TimeSpan.FromSeconds(2));
        _tunnel = ngrok;

        LocalAddress = new Uri($"http://localhost:{port}");
        ExternalAddress = ngrok.HttpsAddress;
        Port = port;
    }
    
    /// Other methods
}
```
Full test with mentioned above scenario looks like this:
```csharp
public sealed class CallbackIntegrationTests : IClassFixture<CallbackServerEmulator>
{
    private readonly CallbackServerEmulator _server;
    private readonly ITestOutputHelper _output;

    public CallbackIntegrationTests(CallbackServerEmulator server, ITestOutputHelper output)
    {
        server.Start();

        _server = server;
        _output = output;
    }

    [Fact]
    public async Task FullPayment_ManualPaymentThruBrowser_Succeeds()
    {
        var connection = new Connection(PlatronClient.PlatronUrl, SettingsStorage.Credentials,
            HttpRequestEncodingType.PostWithQueryString);

        var client = new PlatronClient(connection);

        var initPaymentRequest = new InitPaymentRequest(1.01.Rur(), "verifying resulturl")
                                    {
                                        ResultUrl = _server.ResultUrl,
                                        UserPhone = SettingsStorage.PhoneNumber,
                                        OrderId = Guid.NewGuid().ToString("N"),
                                        NeedUserPhoneNotification = true
                                    };

        // enables only test systems
        //initPaymentRequest.InTestMode();

        var response = await client.InitPaymentAsync(initPaymentRequest);

        // open browser = selenium can be here ^)
        Assert.NotNull(response);
        Assert.NotNull(response.RedirectUrl);
        Browser.Open(response.RedirectUrl);

        // we have some time to manually finish payment.
        var request = _server.WaitForRequest(TimeSpan.FromMinutes(3));
        _output.WriteLine(request.Uri.AbsoluteUri);

        var resultUrl = client.ResultUrl.Parse(request.Uri);

        // to return money back - it's enough to reject payment
        // and hope that your payment service supports it.
        var resultUrlResponse = client.ResultUrl.TryReturnReject(resultUrl, "sorry, my bad...");
        _output.WriteLine(resultUrlResponse.Content);

        request.SendResponse(resultUrlResponse.Content);
    }
}
```
It's simple XUnit test. We can easely start server in ctor but we willn't be able to skip the test without starting and stopping emulator itself (ctor in IClassFixture<T> is called everytime).

All sources has been published as a part of [Platron.Client](https://github.com/sergiorykov/Platron.Client). Feel free to use it and basic idea in your projects :).