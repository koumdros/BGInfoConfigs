Option Explicit
On Error Resume Next
' Modded From:
' https://community.spiceworks.com/scripts/show/1916-ldap-query-to-get-user-s-password-age

Dim sUserName, sReturnedDN, sUserFullDN, iPasswordLastSet, iTimeDifference
Dim wshNetwork, oRootDSE, iDomainMaxAge, sChangeInDays, oADSysInfo, bLocal

' Test if we're using a domain account and act accordingly...
Set oADSysInfo = Createobject("ADSystemInfo")
sUserName = oADSysInfo.UserName
if Err <> 0 then
    'Must be local
    bLocal = True
else
    'Must be AD
    bLocal = False
end if
Set oADSysInfo = Nothing
err.Clear

Set wshNetwork = CreateObject( "WScript.Network" )
sUserName = wshNetwork.UserName

If bLocal then
    Echo GetLocalInfo
Else
    Echo GetDomainInfo
End If

Public Function GetLocalInfo()
    Dim oUsr, seconds
    Set oUsr = GetObject("WinNT://./" & sUserName & ",user")

    Err.Clear
    iPasswordLastSet = oUsr.PasswordAge
    iPasswordLastSet = DateAdd("s", (-1 * iPasswordLastSet), Now())
    If Err <> 0 then
            iPasswordLastSet = "Error getting date"
    End If
    sChangeInDays = ""

    GetLocalInfo = FormatDateTime(iPasswordLastSet, vbShortDate) & sChangeInDays
End Function

Public Function GetDomainInfo
    Set oRootDSE = GetObject("LDAP://rootDSE")

    sReturnedDN = SearchDistinguishedName(sUserName)
    Set sUserFullDN = GetObject("LDAP://" & sReturnedDN)

    iPasswordLastSet = sUserFullDN.PasswordLastChanged
    iTimeDifference = Int(Now - iPasswordLastSet)
    iDomainMaxAge = GetMaxPasswordAge
    If iDomainMaxAge = -1 Then
        sChangeInDays = " (" & iTimeDifference & " days old)"
    Else
        sChangeInDays = " (change in " & (iDomainMaxAge - iTimeDifference) & " days)"
    End If

    Set oRootDSE = Nothing
    Set wshNetwork = Nothing
    Set sUserFullDN = Nothing

    GetDomainInfo = FormatDateTime(iPasswordLastSet, vbShortDate) & sChangeInDays
End Function

Public Function SearchDistinguishedName(ByVal sAccountName)
    ' Function:     SearchDistinguishedName
    ' Description:  Searches the DistinguishedName for a given SamAccountName
    ' Parameters:   ByVal sAccountName - The SamAccountName to search
    ' Returns:      The DistinguishedName Name
    Dim oConnection, oCommand, oRecordSet

    Set oConnection = CreateObject("ADODB.Connection")
    oConnection.Open "Provider=ADsDSOObject;"
    Set oCommand = CreateObject("ADODB.Command")
    oCommand.ActiveConnection = oConnection
    oCommand.CommandText = "<LDAP://" & oRootDSE.get("defaultNamingContext") & _
        ">;(&(objectCategory=User)(samAccountName=" & sAccountName & "));distinguishedName;subtree"
    Set oRecordSet = oCommand.Execute
    On Error Resume Next
    SearchDistinguishedName = oRecordSet.Fields("DistinguishedName")
    If Err.Number <> 0 Then
		SearchDistinguishedName = "Error - Invalid username"
		Err.Clear
	End If
    oConnection.Close
    Set oRecordSet = Nothing
    Set oCommand = Nothing
    Set oConnection = Nothing
End Function

Function GetMaxPasswordAge()
    'Pulls the domain's MaxPasswordAge property
    Dim oDomain, maximumPasswordAge

    set oDomain = getobject("LDAP://" & oRootDSE.get("defaultNamingContext"))

    maximumPasswordAge = int(Int8ToSec(oDomain.get("maxPwdAge")) / 86400) 'convert to days

    If IsNumeric(maximumPasswordAge) Then
        GetMaxPasswordAge = maximumPasswordAge
    Else
        GetMaxPasswordAge = -1
    End If
End Function

Function Int8ToSec(ByVal objInt8)
        ' Function to convert Integer8 attributes from
        ' 64-bit numbers to seconds.
        Dim lngHigh, lngLow
        lngHigh = objInt8.HighPart
        ' Account for error in IADsLargeInteger property methods.
        lngLow = objInt8.LowPart
        If lngLow < 0 Then
            lngHigh = lngHigh + 1
        End If
        Int8ToSec = -(lngHigh * (2 ^ 32) + lngLow) / (10000000)
End Function