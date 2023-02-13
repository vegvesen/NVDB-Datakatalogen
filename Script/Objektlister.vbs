option explicit

!INC Local Scripts.EAConstants-VBScript
!INC NVDB til SOSI.DakatUML2SOSI2PS_1_Klasser_i_kategorier
!INC NVDB til SOSI.DakatUML2SOSI2PS_2_Egenskaper_og_verdier
!INC NVDB til SOSI.DakatUML2SOSI2PS_3_Arv_og_assosiasjoner
!INC NVDB til SOSI.DakatUML2SOSI2PS_4_XMI_og_GML
!INC NVDB._parametre

' Script Name: Objektlister
' Author: Aslak Wold	
' Purpose: Steps 10-12, for making objektlister
' Date: 20221219

function Objektlister

	ObjektlisteKlasser
	ObjektlisterEgenskaperOgVerdier
	ObjektlisterArvOgAssosiasjoner
	ObjektlisterExport
	
	Repository.WriteOutput "Script", "Objektlister ferdig med å kjøre...", 0
	
end function
