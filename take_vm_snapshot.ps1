  #Global variables
  $user = $env:username
  $workingPath = "C:\Users\$user\Desktop\CBSL"
  New-Item -ItemType Directory "$workingPath"
  New-Item -ItemType Directory "$workingPath\bin"
  
  $qemuURL = "https://cloudbase.it/downloads/qemu-img-win-x64-2_3_0.zip"
  $qemuOutput = "C:\Users\$user\Desktop\CBSL\qemu.zip"
  $qemuDestination = "C:\Users\$user\Desktop\CBSL\bin"
  $7zipPath = "C:\Program Files\7-Zip\7z.exe"
  
  $cirrosURL = "http://download.cirros-cloud.net/0.3.4/cirros-0.3.4-x86_64-disk.img"
  $cirrosOutput = "C:\Users\$user\Desktop\CBSL\"
  
  function Get-qemu
  {
    Invoke-WebRequest -Uri $qemuURL -OutFile $qemuOutput
    Expand-Archive $qemuOutput –DestinationPath $qemuDestination
  }
  
  function Get-Cirros
  {
    Invoke-WebRequest -Uri $cirrosURL -DestinationPath $cirrosOutput
    (New-Object System.Net.WebClient).DownloadFile($cirrosURL, $cirrosOutput)
  }
  
  ##################################################################
  function ProcessWMIJob 
  {  
      param 
      (  
          [System.Management.ManagementBaseObject]$Result 
      )  

      if ($Result.ReturnValue -eq 4096) 
      {  
          $Job = [WMI]$Result.Job 

          while ($Job.JobState -eq 4) 
          {  
              Write-Progress $Job.Caption “% Complete” -PercentComplete $Job.PercentComplete 
              Start-Sleep -seconds 1 
              $Job.PSBase.Get() 
          }  
          if ($Job.JobState -ne 7) 
          {  
              Write-Error $Job.ErrorDescription 
              Throw $Job.ErrorDescription 
          }  
          Write-Progress $Job.Caption “Completed” -Completed $TRUE 
      }  
      elseif ($Result.ReturnValue -ne 0) 
      {  
          Write-Error “Hyper-V WMI Job Failed!” 
          Throw $Result.ReturnValue 
      }  
  }

  function Take-Snapshot
  {
    $vmName = "Cirros"
    $VMSnapshotService = Get-WmiObject -Namespace root\virtualization\v2 -Class Msvm_VirtualSystemSnapshotService 
    $SourceVm = Get-WmiObject -Namespace root\virtualization\v2 -Query "Select * From Msvm_ComputerSystem Where ElementName='$vmName'"
    $Result = $VMSnapshotService.CreateSnapshot($SourceVm,"",2)

    ProcessWMIJob($Result)
  }

    if((Get-VM).Name -eq $vmName)
    {
      Take-Snapshot
    }
    else
    {
      Write-Host "No vm with name $vmName was found"
    }  