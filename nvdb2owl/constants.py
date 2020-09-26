#Globale parametere
localPath = "C:\\DATA\\GitHub\\vegvesen\\NVDB-Datakatalogen\\nvdb2owl"

sqFileName=localPath + '\\data\\gdf.sparql'

#proxies = {}
proxies = {'http': 'http://proxy.vegvesen.no:8080'}

nvdbVoPath = "http://rdf.vegdata.no/nvdb/vegobjekt#"
nvdbVnPath = "http://rdf.vegdata.no/nvdb/vegnett#"
nvdbOTLPath = "http://rdf.vegdata.no/nvdb/nvdb-owl#"
gdfOTLPath = "http://rdf.gdf.org/gdf-owl#"
nvdb_otl_gh = 'https://raw.githubusercontent.com/vegvesen/NVDB-Datakatalogen/master/OWL/nvdb-owl.ttl'
gdf_otl_gh = 'https://raw.githubusercontent.com/jetgeo/GIS2OWL/master/GDF/gdf-owl.ttl'
lr_set_gh = 'https://raw.githubusercontent.com/jetgeo/GIS2OWL/master/LRS_NVDB_GDF.ttl'