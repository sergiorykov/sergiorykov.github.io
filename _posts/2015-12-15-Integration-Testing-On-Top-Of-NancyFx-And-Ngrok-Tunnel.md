---
layout: post
title: Integration testing on top of NancyFx and Ngrok tunnel
date: {}
summary: "Simple ideas on making hard staff really easy!"
categories: testing nancyfx ngrok
published: false
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

First one - is as easy as creating first [NancyFx](http://nancyfx.org) module:
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
```
public sealed class Startup
{
    public void Configuration(IAppBuilder app)
    {
          app.UseNancy();
    }
}
```
and integrating thru [Nancy.Owin](https://www.nuget.org/packages/Nancy.Owin) with OWIN host [Microsoft.Owin.Host.HttpListener](https://www.nuget.org/packages/Microsoft.Owin.Host.HttpListener).

Next question is how to make it available externally. It's direct job of tunnelling services like https://forwardhq.com, https://ngrok.com or any similar. 