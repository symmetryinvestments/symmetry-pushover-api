/**
    Implemented in the D Programming Language 2016 by Laeeth Isharc and Kaleidic Associates Advisory UK Limited
    Boost Licensed
    Use at your own risk - this is not tested at all.

    API for pushover notification API
    https://pushover.net/
*/
module kaleidic.api.pushover;

import kaleidic.auth;
import std.stdio;
import std.json;
import std.net.curl;
import std.exception:enforce, assumeUnique;
import std.conv:to;
import std.algorithm:countUntil, map, each;
import std.traits:EnumMembers;
import std.array:array, appender;
import std.format:format;
import std.variant:Algebraic;
import std.typecons:Nullable;
import std.datetime:SysTime, DateTime;

immutable PushoverMessageSounds = [
    "pushover",
    "bike",
    "bugle",
    "cashregister",
    "classical",
    "cosmic",
    "falling",
    "gamelan",
    "incoming",
    "intermission",
    "magic",
    "mechanical",
    "pianobar",
    "siren",
    "spacealarm",
    "tugboat",
    "alien",
    "climb",
    "persistent",
    "echo",
    "updown",
    "none"
];


string joinUrl(string url, string endpoint)
{
    enforce(url.length > 0, "broken url");
    if (url[$-1] == '/')
        url = url[0..$-1];
    return url ~ "/" ~ endpoint;
}


struct PushoverAPI
{
    string endpoint = "https://api.pushover.net/1/";
    string token;
    string userKey = null;

    this(string token)
    {
        this.token = token;
    }
    this(string token, string userKey)
    {
        this.token = token;
        this.userKey = userKey;
    }
}

enum PushoverMessagePriority
{
    lowest = -2,
    low = -1,
    normal = 0,
    high = 1,
    emergency = 2,
}


struct PushoverMessage
{
    string messageText = null;
    string device = null;
    string title = null;
    string url = null;
    string urlTitle = null;
    Nullable!PushoverMessagePriority priority;
    Nullable!SysTime timeStamp;
    string sound = null;

    this(string messageText)
    {
        this.messageText = messageText;
    }
}

auto ref setMessage(ref PushoverMessage message, string messageText)
{
    message.messageText = messageText;
    return message;
}

auto ref setDevice(ref PushoverMessage message, string device)
{
    message.device = device;
    return message;
}

auto ref setTitle(ref PushoverMessage message, string title)
{
    message.title = title;
    return message;
}

auto ref setUrl(ref PushoverMessage message, string url)
{
    message.url = url;
    return message;
}

auto ref setUrlTitle(ref PushoverMessage message, string urlTitle)
{
    message.urlTitle = urlTitle;
    return message;
}
auto ref setPriority(ref PushoverMessage message, PushoverMessagePriority priority)
{
    message.priority = priority;
    return message;
}

auto ref setPriority(ref PushoverMessage message, int priority)
{
    message.priority = priority.to!PushoverMessagePriority;
    return message;
}

auto ref setTimeStamp(ref PushoverMessage message, DateTime timeStamp)
{
    message.timeStamp = cast(SysTime) timeStamp;
    return message;
}

auto ref setTimeStamp(ref PushoverMessage message, SysTime timeStamp)
{
    message.timeStamp = timeStamp;
    return message;
}

auto ref setSound(ref PushoverMessage message, string sound)
{
    message.sound = sound;
    return message;
}

auto sendMessage(PushoverAPI api, PushoverMessage message, string user = null)
{
    JSONValue params;
    if (user is null)
        params["user"] = api.userKey;
    params["message"] = message.messageText;
    if (message.device !is null)
        params["device"] = message.device;
    if (message.title !is null)
        params["title"] = message.title;
    if (message.url !is null)
        params["url"] = message.url;
    if (message.urlTitle !is null)
        params["url_title"] = message.urlTitle;
    if (!message.priority.isNull)
        params["priority"] = message.priority;
    if (!message.timeStamp.isNull)
        params["time_stamp"] = message.timeStamp.toUnixTime;
    if (message.sound !is null)
        params["sound"] = message.sound;
    return api.request("messages.json", HTTP.Method.post, params);
}

auto listGroupMembers(PushoverAPI api, string groupKey)
{
    return api.request("groups/" ~ groupKey ~ ".json", HTTP.Method.get);
}

auto addUserToGroup(PushoverAPI api, string userKey, string groupKey, string device = null, string memo = null)
{
    JSONValue params;
    params["user"] = userKey;
    if (device !is null)
        params["device"] = device;
    if (memo !is null)
        params["memo"] = memo;
    return api.request("groups/" ~ groupKey ~ "/add_user.json", HTTP.Method.post);
}

auto removeUserFromGroup(PushoverAPI api, string userKey, string groupKey)
{
    JSONValue params;
    params["user"] = userKey;
    return api.request("groups/" ~ groupKey ~ "/delete_user.json", HTTP.Method.post);
}

auto disableUser(PushoverAPI api, string userKey, string groupKey)
{
    JSONValue params;
    params["user"] = userKey;
    return api.request("groups/" ~ groupKey ~ "/disable_user.json", HTTP.Method.post);
}

auto enableUser(PushoverAPI api, string userKey, string groupKey)
{
    JSONValue params;
    params["user"] = userKey;
    return api.request("groups/" ~ groupKey ~ "/enable_user.json", HTTP.Method.post);
}

auto renameGroup(PushoverAPI api, string oldName, string newName)
{
    JSONValue params;
    params["name"] = newName;
    return api.request("groups/" ~ oldName ~ "/rename.json", HTTP.Method.post);
}
auto listSounds(PushoverAPI api)
{
    return api.request("sounds.json", HTTP.Method.get);
}

auto validate(PushoverAPI api, string user, string device = null)
{
    JSONValue params;
    params["user"] = user;
    if(device.length>0)
        params["device"] = device;
    return api.request("users/validate.json", HTTP.Method.post, params);
}

auto checkReceipt(PushoverAPI api, string receipt)
{
    return api.request("receipts/" ~ receipt ~ ".json");
}

auto cancelEmergencyDelivery(PushoverAPI api, string receipt)
{
    return api.request("receipts/" ~ receipt ~ "/cancel.json");
}

auto assignLicense(PushoverAPI api, string email = null, string os = null)
{
    JSONValue params;
    if (email !is null)
        params["email"] = email;
    if (os !is null)
        params["os"] = os;
    return api.request("licenses/assign.json");
}

string stripQuotes(string s)
{
    if (s.length < 2)
        return s;
    if (s[0] == '"')
        s = s[1..$];
    if (s.length < 1)
        return s;
    if (s[$-1] == '"')
        s = s[0..$-1];
    return s;
}

JSONValue request(PushoverAPI api,
                  string url,
                  HTTP.Method method = HTTP.Method.get,
                  JSONValue params = JSONValue(null))
{
    import std.array:appender;
    import std.uri:encodeComponent;
    import std.conv:to;
    import std.algorithm:canFind;

    enforce(api.token.length > 0, "no token provided");
    auto paramsData = appender!string;
    paramsData.put("token=");
    paramsData.put(api.token.encodeComponent);
    paramsData.put("&");
    if (!params.object.keys.canFind("user"))
    {
        paramsData.put("user=");
        paramsData.put(api.userKey.encodeComponent);
        paramsData.put("&");
    }
    foreach(i, param; params.object.keys)
    {
        if (i > 0)
            paramsData.put("&");
        paramsData.put(param.to!string.encodeComponent);
        paramsData.put("=");
        paramsData.put(params[param].toString.stripQuotes.encodeComponent);
    }

    debug
    {
        writefln("%s", params.toString);
        writefln("%s", paramsData.data.to!string);
    }
    url = api.endpoint.joinUrl(url);
    auto client = HTTP(url);
    auto response = appender!(ubyte[]);
    client.method = method;
    client.setPostData(cast(void[])paramsData.data, "application/x-www-form-urlencoded");
    client.onReceive = (ubyte[] data)
    {
        response.put(data);
        return data.length;
    };
    client.perform(); // rely on curl to throw exceptions on 204, >=500
    return parseJSON(cast(string)response.data);
}

version(StandAlone)
{
    void main(string[] args)
    {
        writefln("%s", pushoverToken());
        writefln("%s", pushoverKey());

        auto api = PushoverAPI(pushoverToken(), pushoverKey());
        PushoverMessage message;
        message = message.setMessage("message text")
        .setTitle("message title")
        .setUrl("google.com")
        .setUrlTitle("google")
        .setPriority(PushoverMessagePriority.high)
        .setTimeStamp(DateTime(2013, 1, 1));
        auto ret = api.sendMessage(message);
        writefln("%s", ret["status"]);
        writefln("%s", ret["request"]);
    }
}
