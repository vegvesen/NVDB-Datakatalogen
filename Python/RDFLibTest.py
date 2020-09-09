from rdflib import Graph, Namespace, URIRef, BNode, Literal
from rdflib.namespace import RDF, FOAF, XSD

g = Graph()

# Parsing a local file
# parsed_graph = g.parse("https://raw.githubusercontent.com/jetgeo/GIS2OWL/master/LRS_NVDB_GDF.owl", format="turtle")

ex = Namespace("http://example.org/")

g.add((ex.Cade, ex.married, ex.Mary))
g.add((ex.France, ex.capital, ex.Paris))
g.add((ex.Cade, ex.age, Literal("27", datatype=XSD.integer)))
g.add((ex.Mary, ex.age, Literal("26", datatype=XSD.integer)))
g.add((ex.Mary, ex.interest, ex.Hiking))
g.add((ex.Mary, ex.interest, ex.Chocolate))
g.add((ex.Mary, ex.interest, ex.Biology))
g.add((ex.Mary, RDF.type, ex.Student))
g.add((ex.Paris, RDF.type, ex.City))
g.add((ex.Paris, ex.locatedIn, ex.France))
g.add((ex.Cade, ex.characteristic, ex.Kind))
g.add((ex.Mary, ex.characteristic, ex.Kind))
g.add((ex.Mary, RDF.type, FOAF.Person))
g.add((ex.Cade, RDF.type, FOAF.Person))

# The turtle format has the purpose of being more readable for humans.
print(g.serialize(format="turtle").decode())
