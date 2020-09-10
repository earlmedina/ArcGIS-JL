# ArcGIS-JL
A Julia wrapper for the ArcGIS  REST API / Julia port of the ArcGIS API for Python.

Example Usage:

using ArcGIS

Signing into GIS
portal_url = "https://www.arcgis.com"
username = "user"
password = "password"

gis = ArcGIS.GIS(url="https://www.arcgis.com")
