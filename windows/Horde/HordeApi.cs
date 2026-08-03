using System.Text;
using System.Text.Json;

namespace Ealain.Horde;

public class HordeApiException : Exception
{
    public HordeApiException(string message) : base(message) { }
    public HordeApiException(string message, Exception inner) : base(message, inner) { }
}

public sealed class HordeTimeoutException : HordeApiException
{
    public HordeTimeoutException() : base("Request to the AI Horde timed out") { }
}

public sealed class HordeDecodingException : HordeApiException
{
    public HordeDecodingException() : base("Failed to decode AI Horde response") { }
}

public sealed class HordeInvalidResponseException : HordeApiException
{
    public int StatusCode { get; }
    public string Content { get; }

    public HordeInvalidResponseException(int statusCode, string content)
        : base($"AI Horde returned {statusCode}")
    {
        StatusCode = statusCode;
        Content = content;
    }
}

public sealed class HordeApi
{
    const string UrlBase = "https://aihorde.net/api/v2";

    public Task<HordeRequestResponse> SubmitRequestAsync(string apiKey, HordeRequest request) =>
        SendAsync<HordeRequestResponse>(HttpMethod.Post, "/generate/async", apiKey, request);

    public Task<HordeCheckRequestResponse> CheckRequestAsync(string apiKey, Guid requestId) =>
        SendAsync<HordeCheckRequestResponse>(HttpMethod.Get, $"/generate/check/{requestId}", apiKey);

    public Task<HordeCheckRequestResponse> FetchRequestAsync(string apiKey, Guid requestId) =>
        SendAsync<HordeCheckRequestResponse>(HttpMethod.Get, $"/generate/status/{requestId}", apiKey);

    static async Task<T> SendAsync<T>(HttpMethod method, string path, string apiKey, object? body = null)
    {
        using var message = new HttpRequestMessage(method, UrlBase + path);
        message.Headers.Add("apikey", apiKey);
        if (body != null)
            message.Content = new StringContent(
                JsonSerializer.Serialize(body, body.GetType()), Encoding.UTF8, "application/json");

        HttpResponseMessage response;
        try
        {
            response = await HttpShared.Client.SendAsync(message);
        }
        catch (TaskCanceledException)
        {
            throw new HordeTimeoutException();
        }
        catch (HttpRequestException ex)
        {
            throw new HordeApiException("Request to the AI Horde failed", ex);
        }

        using (response)
        {
            var content = await response.Content.ReadAsStringAsync();
            if (!response.IsSuccessStatusCode)
                throw new HordeInvalidResponseException((int)response.StatusCode, content);

            try
            {
                return JsonSerializer.Deserialize<T>(content) ?? throw new HordeDecodingException();
            }
            catch (JsonException)
            {
                throw new HordeDecodingException();
            }
        }
    }
}
