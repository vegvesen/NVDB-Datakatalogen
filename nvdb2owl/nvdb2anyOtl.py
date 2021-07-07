# Konvertering av data fra NVDB-RDF til en annen ontologi vha SPARQL

#Importerer biblioteker
import sys, datetime
from rdflib import Graph, Namespace, URIRef,  Literal
from rdflib.namespace import RDF, RDFS, XSD
from constants import *
if not [k for k in sys.path if localPath in k]:
    print('Føyer', localPath, 'til søkestien')
    sys.path.append(localPath)
from nvdb2rdf import *
from sparqlMapping import *

# *********************************
# Her begynner selve moroa!
startTime = datetime.datetime.now()
# Initierer grafer med ontologier
g = Graph()
# Leser ontologier
print(str(datetime.datetime.now()) + ' Leser inn kildeontologien NVDB-OTL fra ', nvdb_otl_gh)
otl_nvdb = Graph()
otl_nvdb.parse(nvdb_otl_gh,format="turtle")
print(str(datetime.datetime.now()) + ' Leser inn målontologien fra ', targetOtl)
otl_target = Graph()
otl_target.parse(targetOtl,format="turtle")
print(str(datetime.datetime.now()) + ' Leser inn linkset fra ', lr_set)
otl_lset = Graph()
otl_lset.parse(lr_set,format="turtle")
#Slår sammen alle ontologier til en stor graf
otl = Graph()
otl = otl_nvdb + otl_target + otl_lset

# Leser graf med NVDB-data
g_nvdb = Graph()
# vegobjekttype=174
# område='FronSel'
# Alt.1: Fra NVDB-API
for knr in range (knrfrom,knrto):
    print(str(datetime.datetime.now()) + ' Kommune: ' + str(knr))
    try:
        # Lager graf fra NVDB-data
        g_nvdb=g_nvdb + nvdb2graph(featuretypeid,knr,otl_nvdb)
    except:
        print(str(datetime.datetime.now()) + ' Ukjent kommune: ' + str(knr))

# Alt.2: Fra fil
#nvdbfile=localPath + "\\data\\" + område + "_" + str(vegobjekttype) + ".ttl."
#print(str(datetime.datetime.now()) + ' Leser NVDB-RDF fra ', nvdbfile)
#g_nvdb.parse(nvdbfile, format="turtle")

# Lager graf med både OTL og individer
gOTL = otl + g_nvdb

# Konvertering til GDF vha SPARQL
target_g = sqFileProcess(sqFileName,gOTL)
# Namespace for målontologi
target_g.bind(targetNs, Namespace(targetOTLPath))
# Namespace for NVDB og Geosparql
target_g.bind("nvdb_vo", Namespace(nvdbVoPath))
target_g.bind("nvdb_otl",Namespace(nvdbOTLPath))
target_g.bind("gsp",'http://www.opengis.net/ont/geosparql#')

#gdf_g = gdf_g + otl_gdf
print('')
targetFile=localPath + "\\data\\" + targetNs + "_" + areaname + "_" + str(featuretypeid) + ".ttl."
print(str(datetime.datetime.now()) + ' Skriver til målfil ' + targetFile)
target_g.serialize(destination=targetFile, format="turtle")

timePassed =datetime.datetime.now() - startTime
print(str(datetime.datetime.now()) + ' Ferdig! Tidsforbruk: ' + str(timePassed) + ')')
