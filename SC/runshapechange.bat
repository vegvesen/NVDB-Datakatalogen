"C:\Program Files (x86)\AdoptOpenJDK\jre-14.0.1.7-hotspot\bin\java.exe" -Xms256m -Xmx1024m -Dfile.encoding=UTF-8 -jar "C:\DATA\Programvare\ShapeChange-2.9.1\ShapeChange-2.9.1.jar" -c "C:\DATA\GitHub\vegvesen\NVDB-Datakatalogen\SC\config\ShapeChangeConfiguration.xml"
Mkdir C:\DATA\GitHub\vegvesen\NVDB-Datakatalogen\GML
Move C:\DATA\GitHub\vegvesen\NVDB-Datakatalogen\SC\XSD\INPUT\470.xsd C:\DATA\GitHub\vegvesen\NVDB-Datakatalogen\GML\
Del /Q C:\DATA\GitHub\vegvesen\NVDB-Datakatalogen\SC\XSD\INPUT\*.*
Pause
