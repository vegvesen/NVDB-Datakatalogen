# Generering av PropertySetDefinitions-Ontologier for NVDB

nvdb_otl_local = 'C:\\DATA\\GitHub\\vegvesen\\NVDB-Datakatalogen\\OWL\\core\\nvdb-owl.ttl'
nvdb_kat_local = 'C:\\DATA\\GitHub\\vegvesen\\NVDB-Datakatalogen\\OWL\\category\\nvdb-kategorier.ttl'
result_otl_local = 'C:\\DATA\\GitHub\\vegvesen\\NVDB-Datakatalogen\\OWL\\ifc\\psd-owl.ttl'
res_file = 'C:\\DATA\\GitHub\\vegvesen\\NVDB-Datakatalogen\\OWL\\ifc\\nvdb-psd.ttl'
sqFileName = 'C:\\DATA\\GitHub\\vegvesen\\NVDB-Datakatalogen\\OWL\\ifc\\nvdb-psd.sparql'
vot_kat = 303 #NVDB-Data SVV

versionQ="""PREFIX owl: <http://www.w3.org/2002/07/owl#> SELECT DISTINCT ?vi WHERE {?o owl:versionInfo ?vi .} """

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
otl_nvdb = Graph()
otl_res = Graph()
# Leser NVDB-ontologi
print(str(datetime.datetime.now()) + ' Leser inn ontologi for NVDB fra ', nvdb_otl_local)
otl_nvdb.parse(nvdb_otl_local,format="turtle")
# Finner versjonsnummer fra ontologien
vi = 'Ukjent'
q_res = otl_nvdb.query(versionQ)
for row in q_res:
    vi = str(row.vi)
    print(str(datetime.datetime.now()) + ' Versjonsnummer: ', vi)
    print(str(datetime.datetime.now()) + ' Mappingen begrenses til vegobjekttypekategori : ', vot_kat)
print(str(datetime.datetime.now()) + ' Leser inn NVDB-kategorisering fra ', nvdb_kat_local)
otl_kat = Graph()
otl_kat.parse(nvdb_kat_local,format="turtle")
#Resultatontologi og SPARQL-fil for mapping
print(str(datetime.datetime.now()) + ' Leser inn ontologi for resultatstruktur fra ', result_otl_local)
otl_res.parse(result_otl_local,format="turtle")
otl_merge = otl_nvdb + otl_kat + otl_res
print(str(datetime.datetime.now()) + ' SPARQL-fil for mapping: ', sqFileName)

otl_mapped = Graph()
#Heading - kan hentes fra fil med innstilinger eller en kjerneontologi
otl_mapped.bind("nvdb", Namespace("https://ontologi.atlas.vegvesen.no/nvdb/core/nvdb-owl#"))
otl_mapped.bind("psd", Namespace("https://raw.githubusercontent.com/vegvesen/NVDB-Datakatalogen/master/OWL/ifc/psd-owl#"))
otl_mapped.bind("owl", Namespace("http://www.w3.org/2002/07/owl#"))
otl_mapped.bind("rdfs", Namespace("http://www.w3.org/2000/01/rdf-schema#"))
otl_mapped.bind("xsd", Namespace("http://www.w3.org/2001/XMLSchema#"))
otl_mapped.bind("dc", Namespace("http://purl.org/dc/elements/1.1/"))


ont = URIRef('https://ontologi.atlas.vegvesen.no/nvdb/nvdb-psd')
otl_mapped.add((ont, RDF.type, OWL.Ontology))
otl_mapped.add((ont, OWL.imports, URIRef('https://raw.githubusercontent.com/vegvesen/NVDB-Datakatalogen/master/OWL/ifc/psd-owl.ttl')))
otl_mapped.add((ont, OWL.versionInfo, Literal(vi, datatype=XSD.string)))
otl_mapped.add((ont, DC.creator, Literal('SVV', datatype=XSD.string)))
otl_mapped.add((ont, DC.description, Literal('IFC PropertySetDefintions for NVDB Datakatalogen', datatype=XSD.string)))
otl_mapped.add((ont, DC.title, Literal('NVDB Poperty Set Definitions', datatype=XSD.string)))
sq_g = sqFileProcess(sqFileName, otl_merge, "[kid]", str(vot_kat))
otl_mapped = otl_mapped + sq_g
#
# katFile = "C:\\DATA\\GitHub\\vegvesen\\NVDB-Datakatalogen\\OWL\\category\\nvdb-kategori-" + str(row.kid) + ".ttl."
print(str(datetime.datetime.now()) + ' Skriver ' + str(len(otl_mapped)) + ' tripler til filen ' + res_file)
otl_mapped.serialize(destination=res_file, format="turtle")

print(str(datetime.datetime.now()) + '  ')

timePassed =datetime.datetime.now() - startTime
print(str(datetime.datetime.now()) + ' Ferdig! Tidsforbruk: ' + str(timePassed) + ')')
