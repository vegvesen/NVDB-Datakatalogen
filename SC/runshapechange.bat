JAVA -Xms256m -Xmx1024m -Dfile.encoding=UTF-8 -jar "C:\Programfiler\ShapeChange-2.11.0\ShapeChange-2.11.0.jar" -c "C:\DATA\GitHub\vegvesen\NVDB-Datakatalogen\SC\config\ShapeChangeConfiguration.xml"

Mkdir C:\DATA\GitHub\vegvesen\NVDB-Datakatalogen\GML
Move C:\DATA\GitHub\vegvesen\NVDB-Datakatalogen\SC\XSD\INPUT\470.xsd C:\DATA\GitHub\vegvesen\NVDB-Datakatalogen\GML\
Del /Q C:\DATA\GitHub\vegvesen\NVDB-Datakatalogen\SC\XSD\INPUT\*.*
Pause
