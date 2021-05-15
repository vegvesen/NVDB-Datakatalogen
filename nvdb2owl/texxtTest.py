
query = """# Finn kodelister (klasser) som skal være med
# lag kopi for kategorien som subtype under eksisterende kodeliste
# Angi egen label på den kopierte kodelista
# Knytt kodeverdier til den kopierte kodelista
PREFIX owl: <http://www.w3.org/2002/07/owl#>
PREFIX nvdb: <http://rdf.vegdata.no/nvdb/nvdb-owl#>
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
CONSTRUCT {
    ?votkat_kl a owl:Class .
    ?votkat_kl rdfs:subClassOf ?kl .
    ?votkat_kl rdfs:label ?votkat_kln .
    #?tv a ?votkat_kl .
}
WHERE { 
    ?et nvdb:medlem_av_VOTKategori ?k .
    ?k rdfs:subClassOf+ nvdb:Vegobjekttypekategori .
    ?k nvdb:nvdb_navn ?kn .
    ?k nvdb:nvdb_id ?kid .
    ?k nvdb:nvdb_id [kid] .
    ?et rdfs:range ?kl .
    ?kl nvdb:nvdb_navn ?kln .    
    #?tv a ?kl .
    #?tv nvdb:medlem_av_VOTKategori ?k .
    BIND (URI(CONCAT(str(?kl),"_votkat",str(?kid))) AS ?votkat_kl) .
    BIND (CONCAT(str(?kln)," (",str(?kn),")") AS ?votkat_kln) .
} """

query = "test kid replace"
query.replace("kid","302")


query=query.replace("kid", "302")
# Prints the string by replacing geeks by Geeks



print(query)
