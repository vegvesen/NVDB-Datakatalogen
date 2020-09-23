from osgeo import ogr

# Create test polygon
ring = ogr.Geometry(ogr.wkbLinearRing)
ring.AddPoint(1179091.1646903288, 712782.8838459781)
ring.AddPoint(1161053.0218226474, 667456.2684348812)
ring.AddPoint(1214704.933941905, 641092.8288590391)
ring.AddPoint(1228580.428455506, 682719.3123998424)
ring.AddPoint(1218405.0658121984, 721108.1805541387)
ring.AddPoint(1179091.1646903288, 712782.8838459781)
poly = ogr.Geometry(ogr.wkbPolygon)
poly.AddGeometry(ring)

# Create the output Driver
outDriver = ogr.GetDriverByName('GeoJSON')

# Create the output GeoJSON
outDataSource = outDriver.CreateDataSource('test.geojson')
outLayer = outDataSource.CreateLayer('test.geojson', geom_type=ogr.wkbPolygon )

# Get the output Layer's Feature Definition
featureDefn = outLayer.GetLayerDefn()

# create a new feature
outFeature = ogr.Feature(featureDefn)

# Set new geometry
outFeature.SetGeometry(poly)

# Add new feature to output Layer
outLayer.CreateFeature(outFeature)

# dereference the feature
outFeature = None

# Save and close DataSources
outDataSource = None