#Globale parametere
featuretypeid = 105
areaname = 'hamar'
lstKnr=[3403]   #range(3403,3404)
oneFile = False


localPath = "C:\\DATA\\GitHub\\vegvesen\\NVDB-Datakatalogen\\owl"
scriptPath = localPath + "\\script"

# NVDB-filnavn ut fra utvalgsparametre
nvdbfile=localPath + "\\data\\nvdb_" + areaname + "_" + str(featuretypeid) + ".ttl."

#målontologi
targetOtl = 'https://raw.githubusercontent.com/jetgeo/GIS2OWL/master/GDF/gdf-owl.ttl'
targetOTLPath = "http://rdf.gdf.org/gdf-owl#"
targetNs = "gdf"
targetFile= localPath + "\\data\\" + targetNs + "_" + areaname + "_" + str(featuretypeid) + ".ttl."
sqFileName=localPath + '\\lrs\\nvdb2gdf.sparql'


#linking rule set
lr_set = 'https://raw.githubusercontent.com/vegvesen/NVDB-Datakatalogen/master/OWL/lrs/lrs_nvdb_gdf.ttl'

#proxies = {}
proxies = {'http': 'http://proxy.vegvesen.no:8080'}

nvdbVoPath = "https://ontologi.atlas.vegvesen.no/nvdb/core/nvdb-owl/vegobjekt#"
nvdbVnPath = "https://ontologi.atlas.vegvesen.no/nvdb/core/vegnett#"
nvdbOTLPath = "https://ontologi.atlas.vegvesen.no/nvdb/core/nvdb-owl#"
gdfOTLPath = "http://rdf.gdf.org/gdf-owl#"
nvdb_otl_gh = 'https://raw.githubusercontent.com/vegvesen/NVDB-Datakatalogen/master/OWL/core/nvdb-owl.ttl'
nvdb_kat_gh = 'https://raw.githubusercontent.com/vegvesen/NVDB-Datakatalogen/master/OWL/core/nvdb-kategorier.ttl'
gdf_otl_gh = 'https://raw.githubusercontent.com/jetgeo/GIS2OWL/master/GDF/gdf-owl.ttl'
lr_set_gh = 'https://raw.githubusercontent.com/vegvesen/NVDB-Datakatalogen/master/OWL/linkset/LRS_NVDB_GDF.ttl'

rdfsUri = "http://www.w3.org/2000/01/rdf-schema#"
gspURI = "http://www.opengis.net/ont/geosparql#"