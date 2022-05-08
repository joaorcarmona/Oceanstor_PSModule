function Start-Huawei_RestSession {
   [Cmdletbinding()]
 Param(
 [Parameter(ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True,Position=0,Mandatory=$true)]
 [String]$HWMGTHostName,
   [Parameter(ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True,Position=1,Mandatory=$true,ParameterSetName="HWMGTUser")]
 [String]$HWMGTUser,
   [Parameter(ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True,Position=2,Mandatory=$false)]
 [String]$HWMGTPassword,
   [Parameter(ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True,Position=1,Mandatory=$true,ParameterSetName="HWMGTCred")]
 [System.Management.Automation.PSCredential]$HWMGTCred,
    [Switch]$ADUser
 )
    
    switch ($PsCmdlet.ParameterSetName)
    {
        "HWMGTUser" {
            if($HWMGTPassword){
                $HWMGTCred=New-Object System.Management.Automation.PsCredential($HWMGTUser,$(ConvertTo-SecureString -String $HWMGTPassword -AsPlainText -force))
            } else {
                throw "You musst provide a Password for User $HWMGTUser"
            }
        }
        "HWMGTCred" {
            $HWMGTUser=$HWMGTCred.GetNetworkCredential().UserName
            $HWMGTPassword=$HWMGTCred.GetNetworkCredential().Password
        }
    }


    $body = @{username = $HWMGTUser;
             password = $HWMGTPassword;
             scope = if($ADUser){1}else {0}}

    $logonsession=Invoke-RestMethod -Method Post -Uri "https://$($HWMGTHostName):8088/deviceManager/rest/xxxxx/sessions" -Body (ConvertTo-Json $body) -SessionVariable WebSession
    
    $CredentialsBytes = [System.Text.Encoding]::UTF8.GetBytes(-join("{0}:{1}" -f $HWMGTUser,$HWMGTPassword))
    $EncodedCredentials = [Convert]::ToBase64String($CredentialsBytes)
    
    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("Authorization", "Basic $EncodedCredentials")
    $headers.Add("iBaseToken", $logonsession.data.iBaseToken)

    return [pscustomobject]@{
     HWMGTHostName = $HWMGTHostName
     HWMGTCred = $HWMGTCred
     DeviceId=$logonsession.data.deviceid
                    WebSession=$WebSession
                    Headers=$headers
                    iBaseToken=$logonsession.data.iBaseToken
                    error=$logonsession.error
    }
}

function Invoke-Huawei_RestMethod {
   [Cmdletbinding()]
 Param(
 [Parameter(ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True,Position=0,Mandatory=$true)]
 [pscustomobject]$HWMGTSession,
    [Parameter(Position=1,Mandatory=$true)]
    [ValidateSet('GET','POST','PUT','DELETE')]
    [string]$Method,
   [Parameter(ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True,Position=2,Mandatory=$true)]
 [String]$HWMGTRessource,
   [Parameter(ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True,Position=3,Mandatory=$false)]
 [int]$HWMGTRessourceID,
   [Parameter(ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True,Mandatory=$False)]
 [ValidateScript({-not $($_ -inotmatch '^filter=\w*(:{1,2})\w*$|^range=\[\d{1,5}-\d{1,5}\]$')})]
    [string[]]$HWMGTFilters,
   [Parameter(ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True,Mandatory=$false)]
    [System.Collections.Hashtable]$HWMGTRequestBody,
    [Parameter(ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True,Mandatory=$false)]
    [Switch]$PipeLine
 )

    $URI="https://$($HWMGTSession.HWMGTHostName):8088/deviceManager/rest/$($HWMGTSession.DeviceId)/$HWMGTRessource"
    
    if($HWMGTRessourceID){
        $URI+="/$HWMGTRessourceID"
    } elseif($HWMGTFilters) {
        $URI+="?$($HWMGTFilters -join('&'))"
    }

    if($HWMGTRequestBody){
        $result=Invoke-RestMethod -Method $Method -uri $uri -Headers $HWMGTSession.Headers -WebSession $HWMGTSession.WebSession -ContentType "application/json" -Credential $HWMGTSession.HWMGTCred -Body $(ConvertTo-Json $HWMGTRequestBody)
    }else{
        $result=Invoke-RestMethod -Method $Method -uri $uri -Headers $HWMGTSession.Headers -WebSession $HWMGTSession.WebSession -ContentType "application/json" -Credential $HWMGTSession.HWMGTCred
    }
    if ($PipeLine){
        return [pscustomobject]@{
            Result=$result
		    HWMGTSession=$HWMGTSession
		    HWMGTRessource = $HWMGTRessource
		    HWMGTFilters=$HWMGTFilters
            URI=$URI}
        } else {return $result}
}


#$huasession=Start-Huawei_RestSession -HWMGTHostName "10.10.10.25" -HWMGTCred $(Get-Credential)
#$getmodel=Invoke-Huawei_RestMethod $huasession GET 'oem_info/manufactory' 
#$vStoreCount=Invoke-Huawei_RestMethod $huasession GET 'vstore/count' 
#$getAlarms=Invoke-Huawei_RestMethod $huasession GET 'alarm/currentalarm' 
#$getLuns=Invoke-Huawei_RestMethod $huasession GET 'lun'
#$getDisks=Invoke-Huawei_RestMethod $huasession GET 'disk'
$($getDisks | Select -ExpandProperty data)[0] | ft




#$LUNTable=$huarequest|Select -ExpandProperty data data|Select NAME,ParentName,WWN,OWNINGCONTROLLER,ALLOCCAPACITY,ID
#$huarequest | select -ExpandProperty data | select -ExcludeProperty data*

