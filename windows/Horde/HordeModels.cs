using System.Text.Json.Serialization;

namespace Ealain.Horde;

public sealed record HordeParams(
    [property: JsonPropertyName("n")] int N,
    [property: JsonPropertyName("width")] int Width,
    [property: JsonPropertyName("height")] int Height);

public sealed record HordeRequest(
    [property: JsonPropertyName("prompt")] string Prompt,
    [property: JsonPropertyName("style")] string Style,
    [property: JsonPropertyName("params")] HordeParams Params);

public sealed record HordeRequestResponse(
    [property: JsonPropertyName("id")] Guid Id,
    [property: JsonPropertyName("kudos")] float Kudos);

public sealed record HordeGeneration(
    [property: JsonPropertyName("img")] string Img,
    [property: JsonPropertyName("censored")] bool Censored);

public sealed record HordeCheckRequestResponse(
    [property: JsonPropertyName("generations")] List<HordeGeneration>? Generations,
    [property: JsonPropertyName("finished")] int Finished,
    [property: JsonPropertyName("processing")] int Processing,
    [property: JsonPropertyName("restarted")] int Restarted,
    [property: JsonPropertyName("waiting")] int Waiting,
    [property: JsonPropertyName("done")] bool Done,
    [property: JsonPropertyName("faulted")] bool Faulted,
    [property: JsonPropertyName("wait_time")] int WaitTime,
    [property: JsonPropertyName("queue_position")] int QueuePosition,
    [property: JsonPropertyName("kudos")] float Kudos,
    [property: JsonPropertyName("is_possible")] bool IsPossible);
