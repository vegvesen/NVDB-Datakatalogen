proxies = {
    'http': 'http://proxy.vegvesen.no:8080'
}


def get_v440_uris(label):
    url = "http://rdfspatial.vegdata.no:7200/repositories/V440"
    query ="""SELECT ?uri ?label
                WHERE {
                ?uri rdfs:label ?label .
                FILTER(?label="%s"@no)
                }"""%label
    r = requests.get(url, params = {"Accept": "application/json", 'query': query}, proxies=proxies)
    return r.json()["results"]["bindings"]

import requests

get_v440_uris("Underbygning")