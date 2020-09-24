localPath = "C:\\DATA\\GitHub\\vegvesen\\NVDB-Datakatalogen\\nvdb2owl"
rdfFile = localPath + "\\data\\3403_gdf_Gangfelt.ttl"
gdf_otl_gh = 'https://raw.githubusercontent.com/jetgeo/GIS2OWL/master/GDF/gdf-owl.ttl'
gdfOTLPath = "http://rdf.gdf.org/gdf-owl#"
rdfsUri = "http://www.w3.org/2000/01/rdf-schema#"

# SPARQL-oppslag på instanser av GDF-typer
q_prefix = """PREFIX gdf: <http://rdf.gdf.org/gdf-owl#>
            PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>"""

def opm(opuri):
    opm_query = q_prefix + """
                SELECT DISTINCT ?op_uri ?op_code ?op_name  
                WHERE { 
            	?individual a <""" + opuri + """> .
        		?individual ?op_uri ?gdf_val .
       			?gdf_val a ?gdf_valtype .
        		?op_uri rdfs:range ?gdf_valtype .
        		?op_uri rdfs:subPropertyOf+ gdf:gdf_o_properties .
        		?op_uri rdfs:label ?op_name .
        		?op_uri gdf:AttributeTypeCode ?op_code .
            	}
            """
    return opm_query

ft_query = q_prefix + """
            SELECT DISTINCT ?cls ?typename
            WHERE { 
        	?individual a ?cls .
        	?cls rdfs:subClassOf+ gdf:GDF_Feature .
        	?cls rdfs:label ?typename .
        	}"""

import sys, requests,datetime, sqlite3

#Create database
conn = sqlite3.connect(localPath + '\\data\\test.db')
c = conn.cursor()

from rdflib import Graph, Namespace, URIRef, BNode, Literal
from rdflib.namespace import RDF, RDFS, FOAF, XSD

print(str(datetime.datetime.now()) + ' Reading GDF-OTL from ', gdf_otl_gh)
otl_gdf = Graph()
otl_gdf.parse(gdf_otl_gh, format="turtle")
print(str(datetime.datetime.now()) + ' Reading GDF-RDF-dataset from ', rdfFile)
ds_gdf = Graph()
ds_gdf.parse(rdfFile, format="turtle")

#Slår sammen datasett og OTL
g = Graph()
g = otl_gdf + ds_gdf

#TODO: Subgraph with features, data properties and values

#TODO: Subgraph with features and location references


#Finner GDF-objekttyper i datasettet
ft_qres=g.query(ft_query)
ft_cnt = 0
for ft_row in ft_qres:
    print(str(datetime.datetime.now()) + ' GDF Feature Type: ' + ft_row.typename)
    ft_cnt += 1
    # List of object properties in use for this feature type
    omq= opm(str(ft_row.cls))
    op_qres = g.query(omq)
    print(str(datetime.datetime.now()) + ' Object Properties in use for the feature type: ')
    dbCreate = '''CREATE TABLE ''' + str(ft_row.typename).replace(" ","") + ''' ('''
    for op_row in op_qres:
        print(str(datetime.datetime.now()) + ' ' + str(op_row.op_uri) + " code: " + str(op_row.op_code) + " Name: " + str(op_row.op_name))
        dbCreate += str(op_row.op_code) + ''' text,'''
    dbCreate = dbCreate[:-1]
    dbCreate += ''')'''
    # Create table
    print(str(datetime.datetime.now()) + ' Creating database table: ' + dbCreate)
    try:
        c.execute(dbCreate)
    except:
        print(str(datetime.datetime.now()) + ' Table exsists')

    #Finner instanser av den aktuelle objekttypen
    f_cnt = 0
    for fs, fp, fo in g.triples((None, RDF.type, ft_row.cls)):
        print("Feature {}".format(fs) + " of type " + ft_row.typename)
        f_cnt += 1
        #Loop for object properties
        for op_row in op_qres:
            for ps, pp, po in ds_gdf.triples((fs, URIRef(op_row.op_uri), None)):
                #Name of the codelist value
                for ts, tp, to in otl_gdf.triples((po, URIRef(rdfsUri + "label"), None)):
                    vName = format(to)

                print("Object property {}".format(pp) + " (" + str(op_row.op_code) + ") (" + str(op_row.op_name) + ") with value {}".format(po) + " (" + vName + ")")
                #print("Object property {}".format(pp) + " with value {}".format(po))
        #TODO: Loop for data properties

        #TODO: Loop for location referencing

        # Insert a row of data
        # c.execute("INSERT INTO stocks VALUES ('2006-01-05','BUY','RHAT',100,35.14)")

    print(str(datetime.datetime.now()) + ' Counted ' + str(f_cnt) + ' Features of type ' + ft_row.typename)

print(str(datetime.datetime.now()) + ' Counted ' + str(ft_cnt) + ' GDF Feature Types')

# Save (commit) the changes
conn.commit()

# We can also close the connection if we are done with it.
# Just be sure any changes have been committed or they will be lost.
conn.close()

print(str(datetime.datetime.now()) + ' Done!')

