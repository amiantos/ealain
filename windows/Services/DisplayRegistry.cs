using System.Collections.Concurrent;

namespace Ealain.Services;

// Tracks which cached files are currently on screen (per window) so the prune
// job never deletes an image that is being displayed.
public static class DisplayRegistry
{
    static readonly ConcurrentDictionary<Guid, string[]> InUse = new();

    public static void Set(Guid windowId, params string?[] paths) =>
        InUse[windowId] = paths.Where(p => p != null).Cast<string>().ToArray();

    public static void Remove(Guid windowId) => InUse.TryRemove(windowId, out _);

    public static HashSet<string> AllInUse() =>
        InUse.Values.SelectMany(v => v).ToHashSet(StringComparer.OrdinalIgnoreCase);
}
