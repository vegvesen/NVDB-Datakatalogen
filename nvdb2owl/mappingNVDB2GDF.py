# Konvertering av data fra NVDB-RDF til GDF-RDF vha SPARQL

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
print(str(datetime.datetime.now()) + ' Leser inn NVDB-OTL fra ', nvdb_otl_gh)
otl_nvdb = Graph()
otl_nvdb.parse(nvdb_otl_gh,format="turtle")
print(str(datetime.datetime.now()) + ' Leser inn GDF-OTL fra ', gdf_otl_gh)
otl_gdf = Graph()
otl_gdf.parse(gdf_otl_gh,format="turtle")
print(str(datetime.datetime.now()) + ' Leser inn linkset fra ', lr_set_gh)
otl_lset = Graph()
otl_lset.parse(lr_set_gh,format="turtle")
#Slår sammen alle ontologier til en stor graf
otl = Graph()
otl = otl_nvdb + otl_gdf + otl_lset

# Leser graf med NVDB-data
g_nvdb = Graph()
vegobjekttype=174
område='FronSel'
# Alt.1: Fra NVDB-API
for knr in range (3436,3438):
    print(str(datetime.datetime.now()) + ' Kommune: ' + str(knr))
    try:
        # Lager graf fra NVDB-data
        g_nvdb=g_nvdb + nvdb2graph(vegobjekttype,knr,otl_nvdb)
    except:
        print(str(datetime.datetime.now()) + ' Ukjent kommune: ' + str(knr))

# Alt.2: Fra fil
#nvdbfile=localPath + "\\data\\" + område + "_" + str(vegobjekttype) + ".ttl."
#print(str(datetime.datetime.now()) + ' Leser NVDB-RDF fra ', nvdbfile)
#g_nvdb.parse(nvdbfile, format="turtle")

# Lager graf med både OTL og individer
gOTL = otl + g_nvdb

# Konvertering til GDF vha SPARQL
gdf_g = sqFileProcess(sqFileName,gOTL)
gdf_g.bind("gdf", Namespace(gdfOTLPath))
gdf_g.bind("nvdb_vo", Namespace(nvdbVoPath))
gdf_g.bind("nvdb_otl",Namespace(nvdbOTLPath))
gdf_g.bind("gsp",'http://www.opengis.net/ont/geosparql#')

#gdf_g = gdf_g + otl_gdf
print('')
gdffile=localPath + "\\data\\gdf_" + område + "_" + str(vegobjekttype) + ".ttl."
print(str(datetime.datetime.now()) + ' Skriver til GDF-Turtle-fil ' + gdffile)
gdf_g.serialize(destination=gdffile, format="turtle")

timePassed =datetime.datetime.now() - startTime
print(str(datetime.datetime.now()) + ' Ferdig! Tidsforbruk: ' + str(timePassed) + ')')
