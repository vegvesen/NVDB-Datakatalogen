#Globale parametere
featuretypeid = 174
areaname = 'Innlandet'
knrfrom = 3400
knrto=3499

localPath = "C:\\DATA\\GitHub\\vegvesen\\NVDB-Datakatalogen\\owl"
scriptPath = localPath + "\\script"

# NVDB-filnavn ut fra utvalgsparametre
nvdbfile=localPath + "\\data\\NVDB_" + areaname + "_" + str(featuretypeid) + ".ttl."

#målontologi
targetOtl = 'https://raw.githubusercontent.com/jetgeo/GIS2OWL/master/GDF/gdf-owl.ttl'
targetOTLPath = "http://rdf.gdf.org/gdf-owl#"
targetNs = "gdf"
targetFile=localPath + "\\data\\" + targetNs + "_" + areaname + "_" + str(featuretypeid) + ".ttl."


#linking rule set
lr_set = 'https://raw.githubusercontent.com/vegvesen/NVDB-Datakatalogen/master/OWL/linkset/LRS_NVDB_GDF.ttl'

rdfFile = localPath + "\\data\\gdf_Innlandet_174.ttl"
sqFileName=localPath + '\\linkset\\nvdb2gdf.sparql'

#proxies = {}
proxies = {'http': 'http://proxy.vegvesen.no:8080'}

nvdbVoPath = "https://ontologi.utv.atlas.vegvesen.no/nvdb/core/nvdb-owl/vegobjekt#"
nvdbVnPath = "https://ontologi.utv.atlas.vegvesen.no/nvdb/core/vegnett#"
nvdbOTLPath = "https://ontologi.utv.atlas.vegvesen.no/nvdb/core/nvdb-owl#"
gdfOTLPath = "http://rdf.gdf.org/gdf-owl#"
nvdb_otl_gh = 'https://raw.githubusercontent.com/vegvesen/NVDB-Datakatalogen/master/OWL/core/nvdb-owl.ttl'
nvdb_kat_gh = 'https://raw.githubusercontent.com/vegvesen/NVDB-Datakatalogen/master/OWL/core/nvdb-kategorier.ttl'
gdf_otl_gh = 'https://raw.githubusercontent.com/jetgeo/GIS2OWL/master/GDF/gdf-owl.ttl'
lr_set_gh = 'https://raw.githubusercontent.com/vegvesen/NVDB-Datakatalogen/master/OWL/linkset/LRS_NVDB_GDF.ttl'

rdfsUri = "http://www.w3.org/2000/01/rdf-schema#"
gspURI = "http://www.opengis.net/ont/geosparql#"