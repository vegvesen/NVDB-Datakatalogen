#Globale parametere
featuretypeid = 174
areaname = 'Innlandet'
knrfrom = 3400
knrto=3499

localPath = "C:\\DATA\\GitHub\\vegvesen\\NVDB-Datakatalogen\\nvdb2owl"

#målontologi
targetOtl = 'https://raw.githubusercontent.com/jetgeo/GIS2OWL/master/GDF/gdf-owl.ttl'
targetOTLPath = "http://rdf.gdf.org/gdf-owl#"
targetNs = "gdf"
#linking rule set
lr_set = 'https://raw.githubusercontent.com/jetgeo/GIS2OWL/master/LRS_NVDB_GDF.ttl'

rdfFile = localPath + "\\data\\gdf_Innlandet_174.ttl"
sqFileName=localPath + '\\data\\gdf.sparql'

#proxies = {}
proxies = {'http': 'http://proxy.vegvesen.no:8080'}

nvdbVoPath = "http://rdf.vegdata.no/nvdb/vegobjekt#"
nvdbVnPath = "http://rdf.vegdata.no/nvdb/vegnett#"
nvdbOTLPath = "http://rdf.vegdata.no/nvdb/nvdb-owl#"
gdfOTLPath = "http://rdf.gdf.org/gdf-owl#"
nvdb_otl_gh = 'https://raw.githubusercontent.com/vegvesen/NVDB-Datakatalogen/master/OWL/nvdb-owl.ttl'
nvdb_kat_gh = 'https://raw.githubusercontent.com/vegvesen/NVDB-Datakatalogen/master/OWL/nvdb-kategorier.ttl'
gdf_otl_gh = 'https://raw.githubusercontent.com/jetgeo/GIS2OWL/master/GDF/gdf-owl.ttl'
lr_set_gh = 'https://raw.githubusercontent.com/jetgeo/GIS2OWL/master/LRS_NVDB_GDF.ttl'

rdfsUri = "http://www.w3.org/2000/01/rdf-schema#"
gspURI = "http://www.opengis.net/ont/geosparql#"