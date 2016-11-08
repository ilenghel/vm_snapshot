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
              Write-Progress $Job.Caption "% Complete" -PercentComplete $Job.PercentComplete 
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
  
  #Global variables
  $user = $env:username
  $workingPath = "C:\Users\$user\Desktop\CBSL"
  
  #create working directories
  New-Item -ItemType Directory "$workingPath"
  New-Item -ItemType Directory "$workingPath\bin"

  $qemuURL = "https://cloudbase.it/downloads/qemu-img-win-x64-2_3_0.zip"
  $qemuOutput = "C:\Users\$user\Desktop\CBSL\qemu.zip"
  $qemuDestination = "C:\Users\$user\Desktop\CBSL\bin"

  $cirrosURL = "http://download.cirros-cloud.net/0.3.4/cirros-0.3.4-x86_64-disk.img"
  $cirrosOutput = "C:\Users\$user\Desktop\CBSL\"
  $cirrosPath = "$workingPath\cirros-0.3.4-x86_64-disk.img"
  $cirrosVHDX = "$workingPath\cirros.vhdx"
  
  $vmName = "Cirros"

  #download Cirros
  Import-Module BitsTransfer
  Start-BitsTransfer -Source $cirrosURL -Destination $workingPath

  #download QEMU-Img tool
  Start-BitsTransfer -Source $qemuURL -Destination $qemuOutput
  Expand-Archive $qemuOutput -DestinationPath $qemuDestination
  
  #convert cirros.img to cirros.vhdx
  & "$qemuDestination\qemu-img.exe" convert -O vhdx -o subformat=dynamic $cirrosPath $cirrosVHDX
 
  #create VM with 1GB of RAM
  New-VM -Name $vmName -VHDPath $cirrosVHDX -MemoryStartupBytes 1024MB

  #if there is more than one virtual switch created, get the first one's name and connect the VM to it
  if ((Get-VMSwitch).Name -ne $NULL)
  { 
    $swName = (Get-VMSwitch | Select-Object -first 1).Name
    Get-VM -Name $vmName | Get-VMNetworkAdapter | Connect-VMNetworkAdapter -SwitchName $swName
    #bind VM to the existing vSwitch 
  }
  else
  {
    #select the first adapter that has the status UP   
    $netAdapter = (Get-NetAdapter -Physical | Where Status -eq "Up" | Select-Object -first 1).Name
    
    #generate a random number and atach it to vSwitch name
    $random = Get-Random -Minimum 100 -Maximum 999
    $swName = "vSwitch"+$random
    
    #create an external virtual switch using the first adapter (because of -netadaptername parameter the vSwitch will be bound to a phisical NIC)
    New-VMSwitch -NetAdapterName $netAdapter -Name $swName
    
    Get-VM -Name $vmName | Get-VMNetworkAdapter | Connect-VMNetworkAdapter -SwitchName $swName
    #bind VM to the vSwitch created before
  }

  #set VM checkpoint type to Production
  Set-VM -VMName $vmName -CheckpointType Production
    
  #start the VM
  Start-VM -Name $vmName

  #create VM snapshot
  $VMSnapshotService = Get-WmiObject -Namespace root\virtualization\v2 -Class Msvm_VirtualSystemSnapshotService 
  $SourceVm = Get-WmiObject -Namespace root\virtualization\v2 -Query "Select * From Msvm_ComputerSystem Where ElementName='$vmName'"
  $Result = $VMSnapshotService.CreateSnapshot($SourceVm,"",2)
  ProcessWMIJob($Result)
    
