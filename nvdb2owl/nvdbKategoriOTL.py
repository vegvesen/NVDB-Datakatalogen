# Generering av kategorivise Ontologier for NVDB

nvdb_otl_local = 'C:\\DATA\\GitHub\\vegvesen\\NVDB-Datakatalogen\\OWL\\nvdb-owl.ttl'
nvdb_kat_local = 'C:\\DATA\\GitHub\\vegvesen\\NVDB-Datakatalogen\\OWL\\nvdb-kategorier.ttl'
sqFileName = 'C:\\DATA\\GitHub\\vegvesen\\NVDB-Datakatalogen\\OWL\\nvdb-kategorivise-otl.sparql'


katQ = """PREFIX nvdb: <http://rdf.vegdata.no/nvdb/nvdb-owl#>
          PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
          PREFIX owl: <http://www.w3.org/2002/07/owl#>
          SELECT ?k ?kn ?kid 
          WHERE { 
	      ?k rdfs:subClassOf nvdb:Vegobjekttypekategori .
          ?k nvdb:nvdb_navn ?kn .
          ?k nvdb:nvdb_id ?kid .
          FILTER NOT EXISTS {?k rdfs:subClassOf nvdb:Vegobjekttype } .
          } """

versionQ="""PREFIX owl: <http://www.w3.org/2002/07/owl#>
          SELECT DISTINCT ?vi
          WHERE { 
          ?o owl:versionInfo ?vi .
          } """

#Importerer biblioteker
import sys, datetime
from rdflib import Graph, Namespace, URIRef,  Literal
from rdflib.namespace import RDF, RDFS, XSD, OWL,DC
#from constants import *
from sparqlMapping import *

# *********************************
# Her begynner selve moroa!
startTime = datetime.datetime.now()
# Initierer grafer med ontologier

# Leser ontologier
print(str(datetime.datetime.now()) + ' Leser inn NVDB-OTL fra ', nvdb_otl_local)
otl_nvdb = Graph()
otl_nvdb.parse(nvdb_otl_local,format="turtle")
print(str(datetime.datetime.now()) + ' Leser inn NVDB-kategorier fra ', nvdb_kat_local)
otl_kat = Graph()
otl_kat.parse(nvdb_kat_local,format="turtle")
otl = otl_nvdb + otl_kat

#Finner versionsnummer
vi = 'Ukjent'
q_res=otl.query(versionQ)
for row in q_res:
    vi = str(row.vi)

# Finner og lister alle kategorier
# print('Query: ', katQ)
q_res=otl.query(katQ)
cntRes = 0
for row in q_res:

    # Gjør greiene dine.
    if str(row.kid) == '303' or str(row.kid) == '304':
        print(str(datetime.datetime.now()) + ' Vegobjekttypekategori : ', row.k, ' ', row.kn, '(', row.kid, ')')

        kat_o=Graph()
        kat_o.bind("nvdb", Namespace("http://rdf.vegdata.no/nvdb/nvdb-owl#"))
        kat_o.bind("owl", Namespace("http://www.w3.org/2002/07/owl#"))
        kat_o.bind("rdfs", Namespace("http://www.w3.org/2000/01/rdf-schema#"))
        kat_o.bind("xsd", Namespace("http://www.w3.org/2001/XMLSchema#"))
        kat_o.bind("dc", Namespace("http://purl.org/dc/elements/1.1/"))

        ont = URIRef('http://rdf.vegdata.no/nvdb/nvdb-owl/nvdb-kategori-' + str(row.kid))
        kat_o.add((ont,RDF.type, OWL.Ontology))
        kat_o.add((ont, OWL.imports, URIRef('http://rdf.vegdata.no/nvdb/nvdb-owl')))
        kat_o.add((ont, OWL.versionInfo, Literal(vi, datatype=XSD.string)))
        kat_o.add((ont, DC.creator, Literal('SVV', datatype=XSD.string)))
        kat_o.add((ont, DC.description, Literal('Ontologi for NVDB Datakatalogen vegobjekttypekategori ' + str(row.kn), datatype=XSD.string)))
        kat_o.add((ont, DC.title, Literal('NVDB Datakatalogen vegobjekttypekategori ' + str(row.kn), datatype=XSD.string)))
        kat_g = sqFileProcess(sqFileName, otl,"[kid]",str(row.kid))
        kat_o = kat_o + kat_g

        katFile = "C:\\DATA\\GitHub\\vegvesen\\NVDB-Datakatalogen\\OWL\\nvdb-kategori-" +  str(row.kid) + ".ttl."
        print(str(datetime.datetime.now()) + ' Skriver ' + str(len(kat_o)) + ' tripler til filen ' + katFile)
        kat_o.serialize(destination=katFile, format="turtle")

        cntRes += 1
        print(str(datetime.datetime.now()) + ' Prosessert  ' + str(cntRes) + ' kategorier' )
        print(str(datetime.datetime.now()) + '  ' )

timePassed =datetime.datetime.now() - startTime
print(str(datetime.datetime.now()) + ' Ferdig! Tidsforbruk: ' + str(timePassed) + ')')
