def get_nvdb_ft(vot_id):
    #SPARQL-oppslag på en vegobjekttype
    query ="""PREFIX nvdb: <http://rdf.vegdata.no/nvdb/nvdb-owl#>
                SELECT DISTINCT ?uri ?sosinavn
                WHERE {
                ?uri rdfs:subClassOf+ nvdb:Vegobjekttype .
                ?uri nvdb:nvdb_id """ + vot_id + """ .
                ?uri nvdb:sosi_navn ?sosinavn .}"""
    r = requests.get(url, params = {"Accept": "application/json", 'query': query})
    return r