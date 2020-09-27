# Konvertering av data fra NVDB-API til RDF-format i henhold til NVDB Objekttypebibliotek

#Importerer biblioteker
import sys, datetime
from rdflib import Graph, Namespace
from constants import *

if not [k for k in sys.path if localPath in k]:
    print('Føyer', localPath, 'til søkestien')
    sys.path.append(localPath)
from nvdb2rdf import *

# *********************************
# Her begynner selve moroa!
startTime = datetime.datetime.now()
# Leser NVDB-ontologien
print(str(datetime.datetime.now()) + ' Leser inn NVDB-OTL fra ', nvdb_otl_gh)
otl_nvdb = Graph()
otl_nvdb.parse(nvdb_otl_gh, format="turtle")
# Setter opp graf og namespace-forkortelser for dataene
g_nvdb=Graph()
g_nvdb.bind("nvdb_vo", Namespace(nvdbVoPath))
g_nvdb.bind("nvdb_otl",Namespace(nvdbOTLPath))
g_nvdb.bind("gsp",'http://www.opengis.net/ont/geosparql#')

# Filnavn
vegobjekttype=174
område='Innlandet'
nvdbfile=localPath + "\\data\\" + område + "_" + str(vegobjekttype) + ".ttl."
# Løkke for kommuner
for knr in range (3400,3499):
    print(str(datetime.datetime.now()) + ' Kommune: ' + str(knr))
    try:
        # Lager graf fra NVDB-data
        g_nvdb=g_nvdb + nvdb2graph(vegobjekttype,knr,otl_nvdb)
    except:
        print(str(datetime.datetime.now()) + ' Ukjent kommune: ' + str(knr))

# Skriver til fil (turtle)
print(str(datetime.datetime.now()) + ' Skriver til NVDB-Turtle-fil: ' + nvdbfile)
g_nvdb.serialize(destination=nvdbfile, format="turtle")
timePassed =datetime.datetime.now() - startTime
print(str(datetime.datetime.now()) + ' Ferdig! Tidsforbruk: ' + str(timePassed) + ')')

