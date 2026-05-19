#:package Octokit@14.0.0
#:package Semver@3.0.0
#:package System.Text.Json@10.0.8

using System.Text.Json;

using Octokit;
using Semver;

const string UnifiReleaseUrl = "https://fw-update.ubnt.com/api/firmware?filter=eq~~product~~unifi-controller&filter=eq~~platform~~unix&filter=eq~~channel~~release&sort=-version";

string RepositoryOwner = Environment.GetEnvironmentVariable("GITHUB_REPOSITORY_OWNER")!;
string RepositoryName = "unifi-network-application";
string CommitSha = Environment.GetEnvironmentVariable("GITHUB_SHA")!;
string Token = Environment.GetEnvironmentVariable("GITHUB_TOKEN")!;

var GitHub = new GitHubClient(new ProductHeaderValue("unifi-network-application"))
{
    Credentials = new Credentials(Token)
};
var Http = new HttpClient();

var versions = await GetAllVersions();
var latest = await GetLatestRelease();

var newer = latest is not null ?
    versions
        .Where(x => x.Version is not null)
        .Where(x => x.Version!.ComparePrecedenceTo(latest) > 0)
        .OrderBy(v => v.Version!, SemVersion.PrecedenceComparer)
        .ToList() : versions;

foreach (var version in newer)
{
    var tag = await GetOrCreateTag(version.Version.ToString());

    Console.WriteLine($"Dispatching workflow for version {version.Version} with tag {tag.Ref}");

    await GitHub.Actions.Workflows.CreateDispatch(RepositoryOwner, RepositoryName, "build.yml", new CreateWorkflowDispatch(tag.Ref) { 
        Inputs = new Dictionary<string, object>
        {
            ["version"] = version.Version.ToString(),
            ["url"] = version.Url,
            ["checksum"] = version.Checksum
        }
    });
}

Http.Dispose();

async Task<Reference> GetOrCreateTag(string version)
{
    try
    {
        var tag = await GitHub.Git.Reference.Get(RepositoryOwner, RepositoryName, $"refs/tags/{version}");

        return tag;
    }
    catch (NotFoundException)
    {
        var tag = new NewReference($"refs/tags/{version}", CommitSha);
        return await GitHub.Git.Reference.Create(RepositoryOwner, RepositoryName, tag);
    }
}

async Task<SemVersion?> GetLatestRelease()
{
    try
    {
        var latest = await GitHub.Repository.Release.GetLatest("haythem", "unifi-network-application");
    
        if (latest?.TagName is null) 
            return null;
        
        if (SemVersion.TryParse(latest.TagName, out var version))
            return version;
    }
    catch (NotFoundException)
    {
        return null;
    }

    return null;
}

async Task<IList<UnifiVersion>> GetAllVersions()
{
    var response = await Http.GetAsync(UnifiReleaseUrl);
    response.EnsureSuccessStatusCode();

    var json = await response.Content.ReadAsStringAsync();
    var document = JsonDocument.Parse(json);

    return document.RootElement
        .GetProperty("_embedded")
        .GetProperty("firmware").EnumerateArray()
        .Select(ParseVersion)
        .Where(version => version is not null)
        .Select(version => version!)
        .ToList();
}

UnifiVersion? ParseVersion(JsonElement element)
{
    var major = GetProperty(element, "version_major");
    var minor = GetProperty(element, "version_minor");
    var patch = GetProperty(element, "version_patch");
    var url = GetProperty(element, "_links.data.href");
    var checksum = GetProperty(element, "sha256_checksum");

    return new UnifiVersion(new SemVersion(major.Value.GetInt64(), minor.Value.GetInt64(), patch.Value.GetInt64()), url.Value.GetString(), checksum.Value.GetString());
}

JsonElement? GetProperty(JsonElement element, string property)
{
    ArgumentException.ThrowIfNullOrEmpty(property);

    var segments = property.Split('.', StringSplitOptions.RemoveEmptyEntries);
    return GetPropertyRecursive(element, segments, 0);
}

static JsonElement? GetPropertyRecursive(JsonElement element, string[] segments, int index)
{
    if (index >= segments.Length)
    {
        return element;
    }

    if (!element.TryGetProperty(segments[index], out var next))
    {
        return null;
    }

    return GetPropertyRecursive(next, segments, index + 1);
}

internal record UnifiVersion(SemVersion? Version, string Url, string Checksum);