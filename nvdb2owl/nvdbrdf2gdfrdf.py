# Konvertering av data fra NVDB-RDF til GDF-RDF vha SPARQL

#Importerer biblioteker
import sys, datetime
from rdflib import Graph, Namespace, URIRef,  Literal
from rdflib.namespace import RDF, RDFS, XSD
from constants import *
from nvdb2rdf import nvdb2graph,get_nvdb_ft,get_nvdb_pt,get_nvdb_enum

if not [k for k in sys.path if localPath in k]:
    print('Føyer', localPath, 'til søkestien')
    sys.path.append(localPath)
from nvdbapiv3 import nvdbFagdata

vot=174
kommune=3403

def sqFile2Array(fn):
    #Leser SPARQL-queries fra fil til liste
    sqfile = open(sqFileName,'r',encoding='utf-8')
    Lines = sqfile.readlines()

    qList = [[]]
    qRow = []
    # Leser prefixer i headingen
    strPrefix = ''
    for line in Lines:
        if line.startswith('/'):
            break
        else:
            strPrefix += line
    qRow =['prefix',strPrefix]

    # Leser queries en og en
    curQ = ''
    qName=''
    qCount = 0
    for line in Lines:
        if line.startswith('/'):
            if qCount > 0:
                qRow= [qName,curQ]
            qList.append(qRow)
            qCount += 1
            #print('Query number ', qCount)
            curQ = ''
        elif line.startswith('#NAME'):
            qName = line[6:].replace("\n", " ")
            #print('Query name: ', qName)
        elif qCount > 0:
            curQ += line
    curQ.encode(encoding='utf-8',errors='strict')
    qRow = [qName, curQ]
    qList.append(qRow)
    del qList[0]
    return qList

def sqFileProcess(fn,oGraph):
    #Sekvensiell prosessering av queries fra fil
    #Les queries fra fil, sekvensiell prosessering
    queryList = sqFile2Array(fn)
    i = 0
    res_g=Graph()
    for queryRow in queryList:
        if i == 0:
            prefix=queryList[i][1]
        else:
            print('')
            qName = queryList[i][0]
            print(str(datetime.datetime.now()) + ' Konverteringsspørring : ', qName)
            query = prefix + '\n' + queryList[i][1]
            #print('Query: ', query)
            # Kjører spørring og lager ny graf som resultat
            q_res=oGraph.query(query)
            newg = Graph().parse(data=q_res.serialize(format='xml'))
            res_g += newg
            cntRes = 0
            for subject, predicate, object in newg:
                if not (subject, predicate, object) in newg:
                    raise Exception("Iterator / Container Protocols are Broken!!")
                cntRes += 1
            if cntRes > 0:
                print(str(datetime.datetime.now()) + ' Generert  ' + str(cntRes) + ' tripler' )
            else:
                print(str(datetime.datetime.now()) + ' Ingen matchende tripler')
        i += 1
    return res_g

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
område='Innlandet'
# Alt.1: Fra NVDB-API
for knr in range (3400,3499):
    print(str(datetime.datetime.now()) + ' Kommune: ' + str(knr))
    try:
        # Lager graf fra NVDB-data
        g_nvdb=g_nvdb + nvdb2graph(vegobjekttype,knr)
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

gdf_g = gdf_g + otl_gdf
print('')
gdffile=localPath + "\\data\\gdf_" + område + "_" + str(vegobjekttype) + ".ttl."
print(str(datetime.datetime.now()) + ' Skriver til GDF-Turtle-fil ' + gdffile)
gdf_g.serialize(destination=gdffile, format="turtle")

timePassed =datetime.datetime.now() - startTime
print(str(datetime.datetime.now()) + ' Ferdig! Tidsforbruk: ' + str(timePassed) + ')')
