from pyproj import Transformer
transformer = Transformer.from_crs("EPSG:25833", "EPSG:4326")
print(transformer.transform(50, -80))

#(571666.4475041276, 5539109.815175673)