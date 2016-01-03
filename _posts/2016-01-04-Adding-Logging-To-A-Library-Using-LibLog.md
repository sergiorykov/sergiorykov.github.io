---
layout: post
title: Adding logging to a library using LibLog
date: 2016-01-04T07:00:01.000Z
summary: "Step by step guide"
categories: testing
published: true
---

We needed to add logging support to our library [Platron.Client](https://github.com/sergiorykov/Platron.Client) - API client to payment service [https://platron.ru](https://platron.ru).
What we decided not do: invent a new logger. Therefore there is not so much opportunities. Adding one more constraint - don't add nuget dependency - and there is [LibLog](https://github.com/damianh/LibLog) appears. As for me - it's code due of supporting several platforms and adding compile time options is not readable and easily supportable. But it can be seamlessly integrated with several popular loggers, and one more thing to mention - it [was used in IdentityServer](http://leastprivilege.com/2015/10/22/identityserver3-logging-monitoring-using-serilog-and-seq/).

First of install package [LibLog](https://www.nuget.org/packages/LibLog/). It will place single file in `App_Packages\LibLog.4.2\LibLog.cs`. 

![Installed LibLog]({{ site.url }}/images/liblog/installed.png)

One nice thing is namespace - it was just what doctor ordered:

![Default namespace of LibLog]({{ site.url }}/images/liblog/namespace.png)

In our case we needed to log only couple of things: request, response, exception details. So all integration took several minutes.

{% highlight csharp %}
public sealed class HttpRequestEncoder
{
        private static readonly ILog Logger = LogProvider.For<HttpRequestEncoder>();
        
        // ....
        
        private void LogQueryString(ApiRequest apiRequest, HttpRequestMessage httpRequest)
        {
            Logger.DebugFormat(
                "Executing request: MerchantId={0}, Salt={1}: HttpMethod={2}, RequestUri={3}",
                apiRequest.Plain.MerchantId,
                apiRequest.Plain.Salt,
                httpRequest.Method,
                httpRequest.RequestUri);
        }
}
{% endhighlight %}

Most interesting thing here is how to test it. Test correctness of logged information and make sure that it will really help to find out reasons of errors using library. 
We already have a bunch of integrational tests on XUnit. To see results of our fresh logger we need to [integrate LibLog](https://github.com/damianh/LibLog/wiki/Extending) with [ITestOutputHelper](https://xunit.github.io/docs/capturing-output.html) which provides method to write to test result log.

{% highlight csharp %}
public sealed class LibLogXUnitLogger : ILogProvider
    {
        private readonly ITestOutputHelper _output;

        public LibLogXUnitLogger(ITestOutputHelper output)
        {
            // based on https://github.com/damianh/LibLog/blob/master/src/LibLog.Example.ColoredConsoleLogProvider/ColoredConsoleLogProvider.cs
            _output = output;
        }

        public Logger GetLogger(string name)
        {
            return (logLevel, messageFunc, exception, formatParameters) =>
            {
                if (messageFunc == null)
                {
                    // verifies logging level is enabled
                    return true;
                }

                string message = string.Format(CultureInfo.InvariantCulture, messageFunc(), formatParameters);
                string record = string.Format(
                    CultureInfo.InvariantCulture,
                    "{0} {1} {2}",
                    DateTime.Now,
                    logLevel,
                    message);

                if (exception != null)
                {
                    record = string.Format(
                        CultureInfo.InvariantCulture,
                        "{0}:{1}{2}",
                        record,
                        Environment.NewLine,
                        exception);
                }

                _output.WriteLine(record);
                return true;
            };
        }

        public IDisposable OpenMappedContext(string key, string value)
        {
            return NullDisposable.Instance;
        }

        public IDisposable OpenNestedContext(string message)
        {
            return NullDisposable.Instance;
        }

        private class NullDisposable : IDisposable
        {
            internal static readonly IDisposable Instance = new NullDisposable();

            public void Dispose()
            { }
        }
    }
{% endhighlight %}

Actually it was trickier then I thought, without [sample](https://github.com/damianh/LibLog/blob/master/src/LibLog.Example.ColoredConsoleLogProvider/ColoredConsoleLogProvider.cs) it would be painfull. 

And one last step:

{% highlight csharp %}
public sealed class InitPaymentTests
{
    public InitPaymentTests(ITestOutputHelper output)
    {
        LogProvider.SetCurrentLogProvider(new LibLogXUnitLogger(output));
    }
    
    // Tests ...
}
{% endhighlight %}

Let's run couple of tests and see expected profit :).

{% highlight csharp %}
public sealed class InitPaymentTests
{
        [Theory]
        [InlineData("https://platrondoesnotlivehere.com", "DNS cann't be resolved")]
        [InlineData("http://google.com:3434", "Valid address, but service not available")]
        public async Task InitPayment_PlatronNotAvailableOrNotResolvable_ThrowsServiceNotAvailable(
            string notAvailableUrl, string description)
        {
            var initPayment = new InitPaymentRequest(1.Rur(), "sample description");

            var connection = new Connection(new Uri(notAvailableUrl), new Credentials("0000", "secret"), TimeSpan.FromSeconds(5));
            var client = new PlatronClient(connection);

            await Assert.ThrowsAsync<ServiceNotAvailableApiException>(() => client.InitPaymentAsync(initPayment));
        }
}
{% endhighlight %}

![XUnit output with LibLog integration]({{ site.url }}/images/liblog/xunit.png)

All sources have been published as a part of [Platron.Client](https://github.com/sergiorykov/Platron.Client). Feel free to use it in your projects :).
