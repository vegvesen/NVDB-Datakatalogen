option explicit

!INC Local Scripts.EAConstants-VBScript

' Script Name: Fjern alle constraints
' Author: Knut Jetlund
' Purpose: Fjerner applicationSchema på hovedpakke og legger til på delpakker 
' Date: 20160915
'
' NOTE: Requires a package to be selected in the Project Browser
' 

const ns = "https://raw.githubusercontent.com/jetgeo/NVDBGML/master/XSD/NVDB"

sub main()
	' Show and clear the script output window
	Repository.EnsureOutputVisible "Script"
	Repository.ClearOutput "Script"
	Repository.CreateOutputTab "Error"
	Repository.ClearOutput "Error"
		
	' Get the currently selected package in the tree to work on
	dim thePackage as EA.Package
	set thePackage = Repository.GetTreeSelectedPackage()
		
	if not thePackage is nothing and thePackage.ParentID <> 0 then
		Repository.WriteOutput "Script", Now & " Hovedpakke: " & thePackage.Name & " (" & thePackage.PackageGUID & ")", 0 
		dim tagVal as EA.TaggedValue
		dim i
		for i = 0 to thePackage.Element.TaggedValues.Count-1
			set tagVal = thePackage.Element.TaggedValues.GetAt(i)
			if tagVal.Name="targetNamespace" then
				thePackage.Element.TaggedValues.DeleteAt i, false
			end if	
		next
		thePackage.Element.TaggedValues.Refresh
		
		thePackage.StereotypeEx = ""
		thePackage.Update
		dim pck as EA.Package
		for each pck in thePackage.Packages
			Repository.WriteOutput "Script", Now & " Delpakke: " & pck.Name & " (" & pck.PackageGUID & ")", 0 
			pck.StereotypeEx = "applicationSchema"
			pck.Update
			
			set tagVal = pck.Element.TaggedValues.GetByName("targetNamespace")
			if tagVal is nothing then
				set tagVal = pck.Element.TaggedValues.AddNew("targetNamespace", ns)
			else
				tagval.Value = ns
			end if
            tagVal.Update
		next
				
		Repository.WriteOutput "Script", Now & " Finished, check the Error and Types tabs", 0 
		Repository.EnsureOutputVisible "Script"
	else
		' No package selected in the tree
		MsgBox( "This script requires a package to be selected in the Project Browser." & vbCrLf & _
			"Please select a package in the Project Browser and try again." )
	end if
end sub

main
