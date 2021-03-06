module ArcGIS

using HTTP
using JSON
using JSON3
using Parameters
using DataFrames


######################### GIS TYPE ######################### 
@with_kw mutable struct GIS{T <: String} 
       url::T
       token::T = ""
end

# Function Object used to obtain and set token
function (p::GIS)(username, password)
    portal = p.url
    params = Dict("username"=>username, "password"=>password, "client"=>"referer", "referer"=>portal, "f"=>"json")
    url = "$portal/sharing/rest/generateToken"
    response = HTTP.request("POST", url,
                 ["Content-Type" => "application/x-www-form-urlencoded", "accept"=>"application/json"],
                 HTTP.URIs.escapeuri(params))

    token = JSON3.read(String(response.body))["token"]
    p.token = token
    return "Signed into GIS"
end


######################### FLC TYPE ######################### 
@with_kw mutable struct FeatureLayerCollection
    url::String
    gis::GIS
    properties::JSON3.Object{Base.CodeUnits{UInt8,String},Array{UInt64,1}} = get_properties(url, gis.token)
    layers = properties.layers
    tables = properties.tables
    entities = []
end

function set_entities(p::FeatureLayerCollection) 
    entity_array = append!(Array(p.layers), p.tables)
    fl_urls = ["$(p.url)/$(entity.id)" for entity in entity_array]
    p.entities = [FeatureLayer(url=fl_url, gis=p.gis) for fl_url in fl_urls]
    return "Entities set"
end


######################### FL TYPE ########################## 
@with_kw mutable struct FeatureLayer
    gis::GIS
    url::String
    properties = get_properties(url, gis.token)
    name::String = properties.name
    fs = []
    
end

# Feature Object used to query FeatureLayer and set fs field
function (p::FeatureLayer)(query="1=1", outfields="*") 
    sr = nothing
    fields = []
    geometryType = ""
    features = []
    df = nothing
    params = Dict("token"=>p.gis.token, "f"=>"JSON", "outfields"=>outfields, "where"=>query)
    r = HTTP.request("POST", "$(p.url)/query",
                 ["Content-Type" => "application/x-www-form-urlencoded", "accept"=>"application/json"],
                 HTTP.URIs.escapeuri(params))
    json = JSON.parse(String(r.body))
    
    if "spatialReference" in keys(json)
        sr = json["spatialReference"]
        
    end
    if "fields" in keys(json)
        fields = json["fields"]
        
    end
    if "geometryType" in keys(json)
        geometryType = json["geometryType"]
        
    end
    if "features" in keys(json)
        features = json["features"]
        df_features = []
        for feature in features
            add = feature["attributes"]
            if "geometry" in keys(feature)
                add["geometry"] = feature["geometry"]    
            end
            obj = JSON3.read(JSON.json(add))
            push!(df_features, obj)
        end
        df = DataFrame(df_features)
        
    end
    p.fs = FeatureSet(sr=sr, fields=fields, geometryType=geometryType, features=features, df=df)
    return json
end

# applyEdits - note use of keyword arguments denoted by semicolon
# Adds/Updates/Deletes: json array as String
function applyEdits(FeatureLayer; adds="[]", updates="[]", deletes="[]")
    url = "$(FeatureLayer.url)/applyEdits"
    params = Dict("token"=>FeatureLayer.gis.token, "f"=>"JSON", "adds"=>adds, "updates"=>updates, "deletes"=>deletes)
    r = HTTP.request("POST", url,
                 ["Content-Type" => "application/x-www-form-urlencoded", "accept"=>"application/json"],
                 HTTP.URIs.escapeuri(params))
    r_json = JSON3.read(String(r.body))
    JSON.print(r_json)
end

# Adds/Updates/Deletes: json array as String
function queryAttachments(FeatureLayer; ids, definitionExpression="", useGlobalIds=false, returnUrl=true, returnMetadata=false)
    if useGlobalIds
        globalIds = ids
        objectIds = ""
    else
        objectIds = ids
        globalIds = ""
    end
    url = "$(FeatureLayer.url)/queryAttachments"
    params = Dict("token"=>FeatureLayer.gis.token, "f"=>"JSON", "objectIds"=>objectIds, "globalIds"=>globalIds,
        "definitionExpression"=>definitionExpression, "returnUrl"=>returnUrl, "returnMetadata"=>returnMetadata)
    r = HTTP.request("POST", url,
                 ["Content-Type" => "application/x-www-form-urlencoded", "accept"=>"application/json"],
                 HTTP.URIs.escapeuri(params))
    r_json = JSON3.read(String(r.body))
    JSON.print(r_json)
end


######################### FS TYPE ########################## 
@with_kw mutable struct FeatureSet
    sr = nothing
    fields = []
    geometryType = ""
    features  = []
    df = nothing
end

# General function used to get service/layer properties
function get_properties(url, token)
    params = Dict("token"=>token, "f"=>"JSON")
    r = HTTP.request("POST", url,
                 ["Content-Type" => "application/x-www-form-urlencoded", "accept"=>"application/json"],
                 HTTP.URIs.escapeuri(params))
    r_json = JSON3.read(String(r.body))
    return r_json
end


######################### Other ########################## 
function df_to_json(df::DataFrame)
    jsonarray = []
    len = length(df[:,1])
    indices = names(df)
    for i in 1:len
        record = Dict()
        attr = Dict()
        geometry = nothing
        for index in indices
            if index !== "geometry"
                attr[String(index)] = df[index][i]            
            else
                geometry = df[index][i]            
            end        
        end
        record["attributes"] = attr
        if !isnothing(geometry)
            record["geometry"] = JSON.parse(JSON.json(geometry))
        end
        push!(jsonarray, record)
    end
    return JSON.json(jsonarray)
end

end # module