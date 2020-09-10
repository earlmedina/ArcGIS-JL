# ArcGIS-JL
A Julia wrapper for the ArcGIS  REST API / Julia port of the ArcGIS API for Python.

Example Usage:


## Load Module
```
using ArcGIS
```

<br>

## Sign into GIS
```
portal_url = "https://www.arcgis.com"
username = "user"
password = "password"

gis = ArcGIS.GIS(url="https://www.arcgis.com")
gis(username, password)
```

<br>

## Initialize FeatureLayerCollection Type and set 'entities' field.
This module introduces the concept of the 'entity' - a consolidation of all layers and tables present on a Feature Service. The idea is this helps provide easy assess to any data that might be used for data analysis.
```
url = "https://sampleserver6.arcgisonline.com/arcgis/rest/services/CommercialDamageAssessment/FeatureServer"
flc = ArcGIS.FeatureLayerCollection(url=url, gis=gis)

ArcGIS.set_entities(flc)
```

<br>

## Query Feature Layers and set 'fs' field.
Query functionality is achieved through the use of a Function Object. Below, we cycle through each entity and submit the default '1=1' query. The result is returned as json and also stored as a 'FeatureSet' on the Feature Layer. FeatureSets have the following properties:
    sr: spatial reference as JSON object
    fields: array containing field information
    geometryType: Geometry Type string
    features: Array containing query results
    df = DataFrame created from query results
```
@sync begin
    for entity in flc.entities
        @async begin
            entity()
            println("$(entity.name) queried")
        end
    end
end
```
<br>
 
## Access FeatureLayer DataFrame
This module makes it easy to immediately query data and perform Data Analysis via DataFrames.
```
geom = flc.entities[1].fs.df
```

<br>

## Convert DataFrame to JSON array string
After updating values on a field, you can easily convert a DataFrame to a JSON array string that can be used to push edits.
```
updates = ArcGIS.df_to_json(geom)
```

<br>

## Push updates via apply edits
```
geofl = flc.entities[1]
ArcGIS.applyEdits(geofl, updates=updates)
```
