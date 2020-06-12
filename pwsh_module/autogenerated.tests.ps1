BeforeAll {
  Import-Module -Name (Join-Path (Split-Path $PSCommandPath) 'pwsh_bolt.psm1') -Force

  Mock -ModuleName 'pwsh_bolt' -Verifiable -CommandName Invoke-BoltCommandLine -MockWith {
    return $commandline
  }
}

function Get-HelpCases {
  param($commandName, $parameter, $commandParameters, $helpParameters)
  $helpCases = New-Object System.Collections.Generic.List[PSObject]

  foreach ($parameter in $helpParameters) {
    $currentCase = @{
      commandName            = $commandName
      parameterName          = $parameter.Name
      parameterHelp          = $help.parameters.parameter | Where-Object Name -EQ $parameter.Name
      paramTypeName          = $parameter.Type.Name
      commandSaysisMandatory = $commandParameters | Where-Object name -eq $parameter.name | Select-Object -ExpandProperty IsMandatory
    }
    $helpCases.Add($currentCase) | Out-Null
  }
  return $helpCases
}

function Get-BoltCommandParameters {
  param($command, $common)
  $command.ParameterSets.Parameters |
    Sort-Object -Property Name -Unique |
    Where-Object { $_.Name -notin $common }
}

function Get-BoltCommandHelpParameters {
  param($help, $common)
  ## Without the filter, WhatIf and Confirm parameters are still flagged in "finds help parameter in code" test
  $help.Parameters.Parameter |
    Where-Object { $_.Name -notin $common } |
    Sort-Object -Property Name -Unique
}

function Get-CommonParameters {
  param()
  @(
    'Version', 'Debug', 'ErrorAction', 'ErrorVariable', 'InformationAction',
    'InformationVariable', 'OutBuffer',  'OutVariable', 'PipelineVariable',
    'Verbose', 'WarningAction', 'WarningVariable', 'Confirm', 'Whatif'
  )
}


Describe "Invoke-BoltCommand" {
  $commandName       = 'Invoke-BoltCommand'
  $command           = Get-Command $commandName
  $help              = Get-Help -Name $commandName
  $CommonParameters  = Get-CommonParameters
  $commandParameters = Get-BoltCommandParameters -command $command -common $CommonParameters
  $helpParameters    = Get-BoltCommandHelpParameters -help $help -common $CommonParameters
  $helpCases         = Get-HelpCases -commandName $commandName -parameter $parameter -commandParameters $commandParameters -helpParameters $helpParameters

  Context 'parameters' {
    # Pester 5 doesn't allow outside variables to leak into the `It` block scope
    # anymore. Until the Pester project has a supported workflow for this, the
    # workaround is to inject the data the block needs via a single test case.
    It 'has correct parameters' -TestCases @{command = $command} {
      $command.Parameters['command'] | Should -Be $true
      $command.Parameters['targets'] | Should -Be $true
      $command.Parameters['query'] | Should -Be $true
      $command.Parameters['rerun'] | Should -Be $true
      $command.Parameters['description'] | Should -Be $true
      $command.Parameters['user'] | Should -Be $true
      $command.Parameters['password'] | Should -Be $true
      $command.Parameters['passwordprompt'] | Should -Be $true
      $command.Parameters['privatekey'] | Should -Be $true
      $command.Parameters['hostkeycheck'] | Should -Be $true
      $command.Parameters['ssl'] | Should -Be $true
      $command.Parameters['sslverify'] | Should -Be $true
      $command.Parameters['runas'] | Should -Be $true
      $command.Parameters['sudopassword'] | Should -Be $true
      $command.Parameters['sudopasswordprompt'] | Should -Be $true
      $command.Parameters['sudoexecutable'] | Should -Be $true
      $command.Parameters['concurrency'] | Should -Be $true
      $command.Parameters['inventoryfile'] | Should -Be $true
      $command.Parameters['savererun'] | Should -Be $true
      $command.Parameters['cleanup'] | Should -Be $true
      $command.Parameters['modulepath'] | Should -Be $true
      $command.Parameters['project'] | Should -Be $true
      $command.Parameters['configfile'] | Should -Be $true
      $command.Parameters['transport'] | Should -Be $true
      $command.Parameters['connecttimeout'] | Should -Be $true
      $command.Parameters['tty'] | Should -Be $true
      $command.Parameters['nativessh'] | Should -Be $true
      $command.Parameters['sshcommand'] | Should -Be $true
      $command.Parameters['copycommand'] | Should -Be $true
      $command.Parameters['format'] | Should -Be $true
      $command.Parameters['color'] | Should -Be $true
      $command.Parameters['trace'] | Should -Be $true
      $command.Parameters['loglevel'] | Should -Be $true
    }
    It 'has a primary parameter' -TestCases @{command = $command} {
      $command.Parameters['command'] | Should -Be $true
      $command.Parameters['command'].ParameterSets.Values.IsMandatory | Should -Be $true
    }
  }

  Context 'help' {
    It 'should not be auto-generated' -TestCases @{help = $help} {
      $help.Synopsis | Should -Not -BeNullOrEmpty
      $help.Synopsis | Should -Not -BeLike '*`[`<CommonParameters`>`]*'
    }

    # Should be a description for every function
    It 'gets description' -TestCases @{help = $help} {
      $help.Description | Should -Not -BeNullOrEmpty
    }

    # Should be at least one link
    It 'gets relatedLinks' -TestCases @{help = $help} {
      ($help.relatedLinks | Select-Object -First 1).navigationLink | Should -Not -BeNullOrEmpty
    }

    # My guess is that someday soon, creating a hashtable array in a before block
    # and passing it to the -TestCases parameter will generate the tests you want.
    # For now, the array is out of scope when the file is parsed, so if you don't
    # foreach() loop like this, you don't get any tests. But you still have to inject
    # the data into each test. The Pester project is aware of this limitation
    # and would like to fix it, so some day this loop will go away.
    foreach($case in $helpCases) {
      # Should be a description for every parameter
      It 'gets help for parameter: <parameterName>' -TestCases $case {
        $parameterHelp.Description.Text | Should -Not -BeNullOrEmpty
      }

      # Required value in Help should match IsMandatory property of parameter
      It 'help for <parametername> has correct Mandatory value' -TestCases $case {
        $parameterHelp.Required | Should -Be $commandSaysisMandatory.toString()
      }

      # Parameter type in Help should match code
      It 'help has correct parameter type for <parameterName>' -TestCases $case {
        # To avoid calling Trim method on a null object.
        $helpType = if ($parameterHelp.parameterValue) { $parameterHelp.parameterValue.Trim() }
        $helpType | Should -Be $paramTypeName
      }
    }
  }
}

Describe "Invoke-BoltScript" {
  $commandName       = 'Invoke-BoltScript'
  $command           = Get-Command $commandName
  $help              = Get-Help -Name $commandName
  $CommonParameters  = Get-CommonParameters
  $commandParameters = Get-BoltCommandParameters -command $command -common $CommonParameters
  $helpParameters    = Get-BoltCommandHelpParameters -help $help -common $CommonParameters
  $helpCases         = Get-HelpCases -commandName $commandName -parameter $parameter -commandParameters $commandParameters -helpParameters $helpParameters

  Context 'parameters' {
    # Pester 5 doesn't allow outside variables to leak into the `It` block scope
    # anymore. Until the Pester project has a supported workflow for this, the
    # workaround is to inject the data the block needs via a single test case.
    It 'has correct parameters' -TestCases @{command = $command} {
      $command.Parameters['script'] | Should -Be $true
      $command.Parameters['arguments'] | Should -Be $true
      $command.Parameters['targets'] | Should -Be $true
      $command.Parameters['query'] | Should -Be $true
      $command.Parameters['rerun'] | Should -Be $true
      $command.Parameters['description'] | Should -Be $true
      $command.Parameters['user'] | Should -Be $true
      $command.Parameters['password'] | Should -Be $true
      $command.Parameters['passwordprompt'] | Should -Be $true
      $command.Parameters['privatekey'] | Should -Be $true
      $command.Parameters['hostkeycheck'] | Should -Be $true
      $command.Parameters['ssl'] | Should -Be $true
      $command.Parameters['sslverify'] | Should -Be $true
      $command.Parameters['runas'] | Should -Be $true
      $command.Parameters['sudopassword'] | Should -Be $true
      $command.Parameters['sudopasswordprompt'] | Should -Be $true
      $command.Parameters['sudoexecutable'] | Should -Be $true
      $command.Parameters['concurrency'] | Should -Be $true
      $command.Parameters['inventoryfile'] | Should -Be $true
      $command.Parameters['savererun'] | Should -Be $true
      $command.Parameters['cleanup'] | Should -Be $true
      $command.Parameters['modulepath'] | Should -Be $true
      $command.Parameters['project'] | Should -Be $true
      $command.Parameters['configfile'] | Should -Be $true
      $command.Parameters['transport'] | Should -Be $true
      $command.Parameters['connecttimeout'] | Should -Be $true
      $command.Parameters['tty'] | Should -Be $true
      $command.Parameters['nativessh'] | Should -Be $true
      $command.Parameters['sshcommand'] | Should -Be $true
      $command.Parameters['copycommand'] | Should -Be $true
      $command.Parameters['format'] | Should -Be $true
      $command.Parameters['color'] | Should -Be $true
      $command.Parameters['trace'] | Should -Be $true
      $command.Parameters['loglevel'] | Should -Be $true
      $command.Parameters['tmpdir'] | Should -Be $true
    }
    It 'has a primary parameter' -TestCases @{command = $command} {
      $command.Parameters['script'] | Should -Be $true
      $command.Parameters['script'].ParameterSets.Values.IsMandatory | Should -Be $true
    }
  }

  Context 'help' {
    It 'should not be auto-generated' -TestCases @{help = $help} {
      $help.Synopsis | Should -Not -BeNullOrEmpty
      $help.Synopsis | Should -Not -BeLike '*`[`<CommonParameters`>`]*'
    }

    # Should be a description for every function
    It 'gets description' -TestCases @{help = $help} {
      $help.Description | Should -Not -BeNullOrEmpty
    }

    # Should be at least one link
    It 'gets relatedLinks' -TestCases @{help = $help} {
      ($help.relatedLinks | Select-Object -First 1).navigationLink | Should -Not -BeNullOrEmpty
    }

    # My guess is that someday soon, creating a hashtable array in a before block
    # and passing it to the -TestCases parameter will generate the tests you want.
    # For now, the array is out of scope when the file is parsed, so if you don't
    # foreach() loop like this, you don't get any tests. But you still have to inject
    # the data into each test. The Pester project is aware of this limitation
    # and would like to fix it, so some day this loop will go away.
    foreach($case in $helpCases) {
      # Should be a description for every parameter
      It 'gets help for parameter: <parameterName>' -TestCases $case {
        $parameterHelp.Description.Text | Should -Not -BeNullOrEmpty
      }

      # Required value in Help should match IsMandatory property of parameter
      It 'help for <parametername> has correct Mandatory value' -TestCases $case {
        $parameterHelp.Required | Should -Be $commandSaysisMandatory.toString()
      }

      # Parameter type in Help should match code
      It 'help has correct parameter type for <parameterName>' -TestCases $case {
        # To avoid calling Trim method on a null object.
        $helpType = if ($parameterHelp.parameterValue) { $parameterHelp.parameterValue.Trim() }
        $helpType | Should -Be $paramTypeName
      }
    }
  }
}

Describe "Get-BoltTask" {
  $commandName       = 'Get-BoltTask'
  $command           = Get-Command $commandName
  $help              = Get-Help -Name $commandName
  $CommonParameters  = Get-CommonParameters
  $commandParameters = Get-BoltCommandParameters -command $command -common $CommonParameters
  $helpParameters    = Get-BoltCommandHelpParameters -help $help -common $CommonParameters
  $helpCases         = Get-HelpCases -commandName $commandName -parameter $parameter -commandParameters $commandParameters -helpParameters $helpParameters

  Context 'parameters' {
    # Pester 5 doesn't allow outside variables to leak into the `It` block scope
    # anymore. Until the Pester project has a supported workflow for this, the
    # workaround is to inject the data the block needs via a single test case.
    It 'has correct parameters' -TestCases @{command = $command} {
      $command.Parameters['task'] | Should -Be $true
      $command.Parameters['loglevel'] | Should -Be $true
      $command.Parameters['modulepath'] | Should -Be $true
      $command.Parameters['project'] | Should -Be $true
      $command.Parameters['configfile'] | Should -Be $true
      $command.Parameters['filter'] | Should -Be $true
      $command.Parameters['format'] | Should -Be $true
    }
  }

  Context 'help' {
    It 'should not be auto-generated' -TestCases @{help = $help} {
      $help.Synopsis | Should -Not -BeNullOrEmpty
      $help.Synopsis | Should -Not -BeLike '*`[`<CommonParameters`>`]*'
    }

    # Should be a description for every function
    It 'gets description' -TestCases @{help = $help} {
      $help.Description | Should -Not -BeNullOrEmpty
    }

    # Should be at least one link
    It 'gets relatedLinks' -TestCases @{help = $help} {
      ($help.relatedLinks | Select-Object -First 1).navigationLink | Should -Not -BeNullOrEmpty
    }

    # My guess is that someday soon, creating a hashtable array in a before block
    # and passing it to the -TestCases parameter will generate the tests you want.
    # For now, the array is out of scope when the file is parsed, so if you don't
    # foreach() loop like this, you don't get any tests. But you still have to inject
    # the data into each test. The Pester project is aware of this limitation
    # and would like to fix it, so some day this loop will go away.
    foreach($case in $helpCases) {
      # Should be a description for every parameter
      It 'gets help for parameter: <parameterName>' -TestCases $case {
        $parameterHelp.Description.Text | Should -Not -BeNullOrEmpty
      }

      # Required value in Help should match IsMandatory property of parameter
      It 'help for <parametername> has correct Mandatory value' -TestCases $case {
        $parameterHelp.Required | Should -Be $commandSaysisMandatory.toString()
      }

      # Parameter type in Help should match code
      It 'help has correct parameter type for <parameterName>' -TestCases $case {
        # To avoid calling Trim method on a null object.
        $helpType = if ($parameterHelp.parameterValue) { $parameterHelp.parameterValue.Trim() }
        $helpType | Should -Be $paramTypeName
      }
    }
  }
}

Describe "Invoke-BoltTask" {
  $commandName       = 'Invoke-BoltTask'
  $command           = Get-Command $commandName
  $help              = Get-Help -Name $commandName
  $CommonParameters  = Get-CommonParameters
  $commandParameters = Get-BoltCommandParameters -command $command -common $CommonParameters
  $helpParameters    = Get-BoltCommandHelpParameters -help $help -common $CommonParameters
  $helpCases         = Get-HelpCases -commandName $commandName -parameter $parameter -commandParameters $commandParameters -helpParameters $helpParameters

  Context 'parameters' {
    # Pester 5 doesn't allow outside variables to leak into the `It` block scope
    # anymore. Until the Pester project has a supported workflow for this, the
    # workaround is to inject the data the block needs via a single test case.
    It 'has correct parameters' -TestCases @{command = $command} {
      $command.Parameters['task'] | Should -Be $true
      $command.Parameters['targets'] | Should -Be $true
      $command.Parameters['query'] | Should -Be $true
      $command.Parameters['rerun'] | Should -Be $true
      $command.Parameters['description'] | Should -Be $true
      $command.Parameters['user'] | Should -Be $true
      $command.Parameters['password'] | Should -Be $true
      $command.Parameters['passwordprompt'] | Should -Be $true
      $command.Parameters['privatekey'] | Should -Be $true
      $command.Parameters['hostkeycheck'] | Should -Be $true
      $command.Parameters['ssl'] | Should -Be $true
      $command.Parameters['sslverify'] | Should -Be $true
      $command.Parameters['runas'] | Should -Be $true
      $command.Parameters['sudopassword'] | Should -Be $true
      $command.Parameters['sudopasswordprompt'] | Should -Be $true
      $command.Parameters['sudoexecutable'] | Should -Be $true
      $command.Parameters['concurrency'] | Should -Be $true
      $command.Parameters['inventoryfile'] | Should -Be $true
      $command.Parameters['savererun'] | Should -Be $true
      $command.Parameters['cleanup'] | Should -Be $true
      $command.Parameters['modulepath'] | Should -Be $true
      $command.Parameters['project'] | Should -Be $true
      $command.Parameters['configfile'] | Should -Be $true
      $command.Parameters['transport'] | Should -Be $true
      $command.Parameters['connecttimeout'] | Should -Be $true
      $command.Parameters['tty'] | Should -Be $true
      $command.Parameters['nativessh'] | Should -Be $true
      $command.Parameters['sshcommand'] | Should -Be $true
      $command.Parameters['copycommand'] | Should -Be $true
      $command.Parameters['format'] | Should -Be $true
      $command.Parameters['color'] | Should -Be $true
      $command.Parameters['trace'] | Should -Be $true
      $command.Parameters['loglevel'] | Should -Be $true
      $command.Parameters['params'] | Should -Be $true
      $command.Parameters['tmpdir'] | Should -Be $true
      $command.Parameters['noop'] | Should -Be $true
    }
    It 'has a primary parameter' -TestCases @{command = $command} {
      $command.Parameters['task'] | Should -Be $true
      $command.Parameters['task'].ParameterSets.Values.IsMandatory | Should -Be $true
    }
  }

  Context 'help' {
    It 'should not be auto-generated' -TestCases @{help = $help} {
      $help.Synopsis | Should -Not -BeNullOrEmpty
      $help.Synopsis | Should -Not -BeLike '*`[`<CommonParameters`>`]*'
    }

    # Should be a description for every function
    It 'gets description' -TestCases @{help = $help} {
      $help.Description | Should -Not -BeNullOrEmpty
    }

    # Should be at least one link
    It 'gets relatedLinks' -TestCases @{help = $help} {
      ($help.relatedLinks | Select-Object -First 1).navigationLink | Should -Not -BeNullOrEmpty
    }

    # My guess is that someday soon, creating a hashtable array in a before block
    # and passing it to the -TestCases parameter will generate the tests you want.
    # For now, the array is out of scope when the file is parsed, so if you don't
    # foreach() loop like this, you don't get any tests. But you still have to inject
    # the data into each test. The Pester project is aware of this limitation
    # and would like to fix it, so some day this loop will go away.
    foreach($case in $helpCases) {
      # Should be a description for every parameter
      It 'gets help for parameter: <parameterName>' -TestCases $case {
        $parameterHelp.Description.Text | Should -Not -BeNullOrEmpty
      }

      # Required value in Help should match IsMandatory property of parameter
      It 'help for <parametername> has correct Mandatory value' -TestCases $case {
        $parameterHelp.Required | Should -Be $commandSaysisMandatory.toString()
      }

      # Parameter type in Help should match code
      It 'help has correct parameter type for <parameterName>' -TestCases $case {
        # To avoid calling Trim method on a null object.
        $helpType = if ($parameterHelp.parameterValue) { $parameterHelp.parameterValue.Trim() }
        $helpType | Should -Be $paramTypeName
      }
    }
  }
}

Describe "Get-BoltPlan" {
  $commandName       = 'Get-BoltPlan'
  $command           = Get-Command $commandName
  $help              = Get-Help -Name $commandName
  $CommonParameters  = Get-CommonParameters
  $commandParameters = Get-BoltCommandParameters -command $command -common $CommonParameters
  $helpParameters    = Get-BoltCommandHelpParameters -help $help -common $CommonParameters
  $helpCases         = Get-HelpCases -commandName $commandName -parameter $parameter -commandParameters $commandParameters -helpParameters $helpParameters

  Context 'parameters' {
    # Pester 5 doesn't allow outside variables to leak into the `It` block scope
    # anymore. Until the Pester project has a supported workflow for this, the
    # workaround is to inject the data the block needs via a single test case.
    It 'has correct parameters' -TestCases @{command = $command} {
      $command.Parameters['plan'] | Should -Be $true
      $command.Parameters['loglevel'] | Should -Be $true
      $command.Parameters['modulepath'] | Should -Be $true
      $command.Parameters['project'] | Should -Be $true
      $command.Parameters['configfile'] | Should -Be $true
      $command.Parameters['filter'] | Should -Be $true
      $command.Parameters['format'] | Should -Be $true
    }
  }

  Context 'help' {
    It 'should not be auto-generated' -TestCases @{help = $help} {
      $help.Synopsis | Should -Not -BeNullOrEmpty
      $help.Synopsis | Should -Not -BeLike '*`[`<CommonParameters`>`]*'
    }

    # Should be a description for every function
    It 'gets description' -TestCases @{help = $help} {
      $help.Description | Should -Not -BeNullOrEmpty
    }

    # Should be at least one link
    It 'gets relatedLinks' -TestCases @{help = $help} {
      ($help.relatedLinks | Select-Object -First 1).navigationLink | Should -Not -BeNullOrEmpty
    }

    # My guess is that someday soon, creating a hashtable array in a before block
    # and passing it to the -TestCases parameter will generate the tests you want.
    # For now, the array is out of scope when the file is parsed, so if you don't
    # foreach() loop like this, you don't get any tests. But you still have to inject
    # the data into each test. The Pester project is aware of this limitation
    # and would like to fix it, so some day this loop will go away.
    foreach($case in $helpCases) {
      # Should be a description for every parameter
      It 'gets help for parameter: <parameterName>' -TestCases $case {
        $parameterHelp.Description.Text | Should -Not -BeNullOrEmpty
      }

      # Required value in Help should match IsMandatory property of parameter
      It 'help for <parametername> has correct Mandatory value' -TestCases $case {
        $parameterHelp.Required | Should -Be $commandSaysisMandatory.toString()
      }

      # Parameter type in Help should match code
      It 'help has correct parameter type for <parameterName>' -TestCases $case {
        # To avoid calling Trim method on a null object.
        $helpType = if ($parameterHelp.parameterValue) { $parameterHelp.parameterValue.Trim() }
        $helpType | Should -Be $paramTypeName
      }
    }
  }
}

Describe "Invoke-BoltPlan" {
  $commandName       = 'Invoke-BoltPlan'
  $command           = Get-Command $commandName
  $help              = Get-Help -Name $commandName
  $CommonParameters  = Get-CommonParameters
  $commandParameters = Get-BoltCommandParameters -command $command -common $CommonParameters
  $helpParameters    = Get-BoltCommandHelpParameters -help $help -common $CommonParameters
  $helpCases         = Get-HelpCases -commandName $commandName -parameter $parameter -commandParameters $commandParameters -helpParameters $helpParameters

  Context 'parameters' {
    # Pester 5 doesn't allow outside variables to leak into the `It` block scope
    # anymore. Until the Pester project has a supported workflow for this, the
    # workaround is to inject the data the block needs via a single test case.
    It 'has correct parameters' -TestCases @{command = $command} {
      $command.Parameters['plan'] | Should -Be $true
      $command.Parameters['targets'] | Should -Be $true
      $command.Parameters['query'] | Should -Be $true
      $command.Parameters['rerun'] | Should -Be $true
      $command.Parameters['description'] | Should -Be $true
      $command.Parameters['user'] | Should -Be $true
      $command.Parameters['password'] | Should -Be $true
      $command.Parameters['passwordprompt'] | Should -Be $true
      $command.Parameters['privatekey'] | Should -Be $true
      $command.Parameters['hostkeycheck'] | Should -Be $true
      $command.Parameters['ssl'] | Should -Be $true
      $command.Parameters['sslverify'] | Should -Be $true
      $command.Parameters['runas'] | Should -Be $true
      $command.Parameters['sudopassword'] | Should -Be $true
      $command.Parameters['sudopasswordprompt'] | Should -Be $true
      $command.Parameters['sudoexecutable'] | Should -Be $true
      $command.Parameters['concurrency'] | Should -Be $true
      $command.Parameters['inventoryfile'] | Should -Be $true
      $command.Parameters['savererun'] | Should -Be $true
      $command.Parameters['cleanup'] | Should -Be $true
      $command.Parameters['modulepath'] | Should -Be $true
      $command.Parameters['project'] | Should -Be $true
      $command.Parameters['configfile'] | Should -Be $true
      $command.Parameters['transport'] | Should -Be $true
      $command.Parameters['connecttimeout'] | Should -Be $true
      $command.Parameters['tty'] | Should -Be $true
      $command.Parameters['nativessh'] | Should -Be $true
      $command.Parameters['sshcommand'] | Should -Be $true
      $command.Parameters['copycommand'] | Should -Be $true
      $command.Parameters['format'] | Should -Be $true
      $command.Parameters['color'] | Should -Be $true
      $command.Parameters['trace'] | Should -Be $true
      $command.Parameters['loglevel'] | Should -Be $true
      $command.Parameters['params'] | Should -Be $true
      $command.Parameters['compileconcurrency'] | Should -Be $true
      $command.Parameters['tmpdir'] | Should -Be $true
      $command.Parameters['hieraconfig'] | Should -Be $true
    }
  }

  Context 'help' {
    It 'should not be auto-generated' -TestCases @{help = $help} {
      $help.Synopsis | Should -Not -BeNullOrEmpty
      $help.Synopsis | Should -Not -BeLike '*`[`<CommonParameters`>`]*'
    }

    # Should be a description for every function
    It 'gets description' -TestCases @{help = $help} {
      $help.Description | Should -Not -BeNullOrEmpty
    }

    # Should be at least one link
    It 'gets relatedLinks' -TestCases @{help = $help} {
      ($help.relatedLinks | Select-Object -First 1).navigationLink | Should -Not -BeNullOrEmpty
    }

    # My guess is that someday soon, creating a hashtable array in a before block
    # and passing it to the -TestCases parameter will generate the tests you want.
    # For now, the array is out of scope when the file is parsed, so if you don't
    # foreach() loop like this, you don't get any tests. But you still have to inject
    # the data into each test. The Pester project is aware of this limitation
    # and would like to fix it, so some day this loop will go away.
    foreach($case in $helpCases) {
      # Should be a description for every parameter
      It 'gets help for parameter: <parameterName>' -TestCases $case {
        $parameterHelp.Description.Text | Should -Not -BeNullOrEmpty
      }

      # Required value in Help should match IsMandatory property of parameter
      It 'help for <parametername> has correct Mandatory value' -TestCases $case {
        $parameterHelp.Required | Should -Be $commandSaysisMandatory.toString()
      }

      # Parameter type in Help should match code
      It 'help has correct parameter type for <parameterName>' -TestCases $case {
        # To avoid calling Trim method on a null object.
        $helpType = if ($parameterHelp.parameterValue) { $parameterHelp.parameterValue.Trim() }
        $helpType | Should -Be $paramTypeName
      }
    }
  }
}

Describe "Convert-BoltPlan" {
  $commandName       = 'Convert-BoltPlan'
  $command           = Get-Command $commandName
  $help              = Get-Help -Name $commandName
  $CommonParameters  = Get-CommonParameters
  $commandParameters = Get-BoltCommandParameters -command $command -common $CommonParameters
  $helpParameters    = Get-BoltCommandHelpParameters -help $help -common $CommonParameters
  $helpCases         = Get-HelpCases -commandName $commandName -parameter $parameter -commandParameters $commandParameters -helpParameters $helpParameters

  Context 'parameters' {
    # Pester 5 doesn't allow outside variables to leak into the `It` block scope
    # anymore. Until the Pester project has a supported workflow for this, the
    # workaround is to inject the data the block needs via a single test case.
    It 'has correct parameters' -TestCases @{command = $command} {
      $command.Parameters['plan'] | Should -Be $true
      $command.Parameters['loglevel'] | Should -Be $true
      $command.Parameters['modulepath'] | Should -Be $true
      $command.Parameters['project'] | Should -Be $true
      $command.Parameters['configfile'] | Should -Be $true
    }
  }

  Context 'help' {
    It 'should not be auto-generated' -TestCases @{help = $help} {
      $help.Synopsis | Should -Not -BeNullOrEmpty
      $help.Synopsis | Should -Not -BeLike '*`[`<CommonParameters`>`]*'
    }

    # Should be a description for every function
    It 'gets description' -TestCases @{help = $help} {
      $help.Description | Should -Not -BeNullOrEmpty
    }

    # Should be at least one link
    It 'gets relatedLinks' -TestCases @{help = $help} {
      ($help.relatedLinks | Select-Object -First 1).navigationLink | Should -Not -BeNullOrEmpty
    }

    # My guess is that someday soon, creating a hashtable array in a before block
    # and passing it to the -TestCases parameter will generate the tests you want.
    # For now, the array is out of scope when the file is parsed, so if you don't
    # foreach() loop like this, you don't get any tests. But you still have to inject
    # the data into each test. The Pester project is aware of this limitation
    # and would like to fix it, so some day this loop will go away.
    foreach($case in $helpCases) {
      # Should be a description for every parameter
      It 'gets help for parameter: <parameterName>' -TestCases $case {
        $parameterHelp.Description.Text | Should -Not -BeNullOrEmpty
      }

      # Required value in Help should match IsMandatory property of parameter
      It 'help for <parametername> has correct Mandatory value' -TestCases $case {
        $parameterHelp.Required | Should -Be $commandSaysisMandatory.toString()
      }

      # Parameter type in Help should match code
      It 'help has correct parameter type for <parameterName>' -TestCases $case {
        # To avoid calling Trim method on a null object.
        $helpType = if ($parameterHelp.parameterValue) { $parameterHelp.parameterValue.Trim() }
        $helpType | Should -Be $paramTypeName
      }
    }
  }
}

Describe "Send-BoltFile" {
  $commandName       = 'Send-BoltFile'
  $command           = Get-Command $commandName
  $help              = Get-Help -Name $commandName
  $CommonParameters  = Get-CommonParameters
  $commandParameters = Get-BoltCommandParameters -command $command -common $CommonParameters
  $helpParameters    = Get-BoltCommandHelpParameters -help $help -common $CommonParameters
  $helpCases         = Get-HelpCases -commandName $commandName -parameter $parameter -commandParameters $commandParameters -helpParameters $helpParameters

  Context 'parameters' {
    # Pester 5 doesn't allow outside variables to leak into the `It` block scope
    # anymore. Until the Pester project has a supported workflow for this, the
    # workaround is to inject the data the block needs via a single test case.
    It 'has correct parameters' -TestCases @{command = $command} {
      $command.Parameters['source'] | Should -Be $true
      $command.Parameters['destination'] | Should -Be $true
      $command.Parameters['targets'] | Should -Be $true
      $command.Parameters['query'] | Should -Be $true
      $command.Parameters['rerun'] | Should -Be $true
      $command.Parameters['description'] | Should -Be $true
      $command.Parameters['user'] | Should -Be $true
      $command.Parameters['password'] | Should -Be $true
      $command.Parameters['passwordprompt'] | Should -Be $true
      $command.Parameters['privatekey'] | Should -Be $true
      $command.Parameters['hostkeycheck'] | Should -Be $true
      $command.Parameters['ssl'] | Should -Be $true
      $command.Parameters['sslverify'] | Should -Be $true
      $command.Parameters['runas'] | Should -Be $true
      $command.Parameters['sudopassword'] | Should -Be $true
      $command.Parameters['sudopasswordprompt'] | Should -Be $true
      $command.Parameters['sudoexecutable'] | Should -Be $true
      $command.Parameters['concurrency'] | Should -Be $true
      $command.Parameters['inventoryfile'] | Should -Be $true
      $command.Parameters['savererun'] | Should -Be $true
      $command.Parameters['cleanup'] | Should -Be $true
      $command.Parameters['modulepath'] | Should -Be $true
      $command.Parameters['project'] | Should -Be $true
      $command.Parameters['configfile'] | Should -Be $true
      $command.Parameters['transport'] | Should -Be $true
      $command.Parameters['connecttimeout'] | Should -Be $true
      $command.Parameters['tty'] | Should -Be $true
      $command.Parameters['nativessh'] | Should -Be $true
      $command.Parameters['sshcommand'] | Should -Be $true
      $command.Parameters['copycommand'] | Should -Be $true
      $command.Parameters['format'] | Should -Be $true
      $command.Parameters['color'] | Should -Be $true
      $command.Parameters['trace'] | Should -Be $true
      $command.Parameters['loglevel'] | Should -Be $true
      $command.Parameters['tmpdir'] | Should -Be $true
    }
    It 'has a primary parameter' -TestCases @{command = $command} {
      $command.Parameters['source'] | Should -Be $true
      $command.Parameters['source'].ParameterSets.Values.IsMandatory | Should -Be $true
    }
    It 'has a primary parameter' -TestCases @{command = $command} {
      $command.Parameters['destination'] | Should -Be $true
      $command.Parameters['destination'].ParameterSets.Values.IsMandatory | Should -Be $true
    }
  }

  Context 'help' {
    It 'should not be auto-generated' -TestCases @{help = $help} {
      $help.Synopsis | Should -Not -BeNullOrEmpty
      $help.Synopsis | Should -Not -BeLike '*`[`<CommonParameters`>`]*'
    }

    # Should be a description for every function
    It 'gets description' -TestCases @{help = $help} {
      $help.Description | Should -Not -BeNullOrEmpty
    }

    # Should be at least one link
    It 'gets relatedLinks' -TestCases @{help = $help} {
      ($help.relatedLinks | Select-Object -First 1).navigationLink | Should -Not -BeNullOrEmpty
    }

    # My guess is that someday soon, creating a hashtable array in a before block
    # and passing it to the -TestCases parameter will generate the tests you want.
    # For now, the array is out of scope when the file is parsed, so if you don't
    # foreach() loop like this, you don't get any tests. But you still have to inject
    # the data into each test. The Pester project is aware of this limitation
    # and would like to fix it, so some day this loop will go away.
    foreach($case in $helpCases) {
      # Should be a description for every parameter
      It 'gets help for parameter: <parameterName>' -TestCases $case {
        $parameterHelp.Description.Text | Should -Not -BeNullOrEmpty
      }

      # Required value in Help should match IsMandatory property of parameter
      It 'help for <parametername> has correct Mandatory value' -TestCases $case {
        $parameterHelp.Required | Should -Be $commandSaysisMandatory.toString()
      }

      # Parameter type in Help should match code
      It 'help has correct parameter type for <parameterName>' -TestCases $case {
        # To avoid calling Trim method on a null object.
        $helpType = if ($parameterHelp.parameterValue) { $parameterHelp.parameterValue.Trim() }
        $helpType | Should -Be $paramTypeName
      }
    }
  }
}

Describe "Install-BoltPuppetfile" {
  $commandName       = 'Install-BoltPuppetfile'
  $command           = Get-Command $commandName
  $help              = Get-Help -Name $commandName
  $CommonParameters  = Get-CommonParameters
  $commandParameters = Get-BoltCommandParameters -command $command -common $CommonParameters
  $helpParameters    = Get-BoltCommandHelpParameters -help $help -common $CommonParameters
  $helpCases         = Get-HelpCases -commandName $commandName -parameter $parameter -commandParameters $commandParameters -helpParameters $helpParameters

  Context 'parameters' {
    # Pester 5 doesn't allow outside variables to leak into the `It` block scope
    # anymore. Until the Pester project has a supported workflow for this, the
    # workaround is to inject the data the block needs via a single test case.
    It 'has correct parameters' -TestCases @{command = $command} {
      $command.Parameters['loglevel'] | Should -Be $true
      $command.Parameters['modulepath'] | Should -Be $true
      $command.Parameters['project'] | Should -Be $true
      $command.Parameters['configfile'] | Should -Be $true
      $command.Parameters['puppetfile'] | Should -Be $true
    }
  }

  Context 'help' {
    It 'should not be auto-generated' -TestCases @{help = $help} {
      $help.Synopsis | Should -Not -BeNullOrEmpty
      $help.Synopsis | Should -Not -BeLike '*`[`<CommonParameters`>`]*'
    }

    # Should be a description for every function
    It 'gets description' -TestCases @{help = $help} {
      $help.Description | Should -Not -BeNullOrEmpty
    }

    # Should be at least one link
    It 'gets relatedLinks' -TestCases @{help = $help} {
      ($help.relatedLinks | Select-Object -First 1).navigationLink | Should -Not -BeNullOrEmpty
    }

    # My guess is that someday soon, creating a hashtable array in a before block
    # and passing it to the -TestCases parameter will generate the tests you want.
    # For now, the array is out of scope when the file is parsed, so if you don't
    # foreach() loop like this, you don't get any tests. But you still have to inject
    # the data into each test. The Pester project is aware of this limitation
    # and would like to fix it, so some day this loop will go away.
    foreach($case in $helpCases) {
      # Should be a description for every parameter
      It 'gets help for parameter: <parameterName>' -TestCases $case {
        $parameterHelp.Description.Text | Should -Not -BeNullOrEmpty
      }

      # Required value in Help should match IsMandatory property of parameter
      It 'help for <parametername> has correct Mandatory value' -TestCases $case {
        $parameterHelp.Required | Should -Be $commandSaysisMandatory.toString()
      }

      # Parameter type in Help should match code
      It 'help has correct parameter type for <parameterName>' -TestCases $case {
        # To avoid calling Trim method on a null object.
        $helpType = if ($parameterHelp.parameterValue) { $parameterHelp.parameterValue.Trim() }
        $helpType | Should -Be $paramTypeName
      }
    }
  }
}

Describe "Get-BoltPuppetfileModules" {
  $commandName       = 'Get-BoltPuppetfileModules'
  $command           = Get-Command $commandName
  $help              = Get-Help -Name $commandName
  $CommonParameters  = Get-CommonParameters
  $commandParameters = Get-BoltCommandParameters -command $command -common $CommonParameters
  $helpParameters    = Get-BoltCommandHelpParameters -help $help -common $CommonParameters
  $helpCases         = Get-HelpCases -commandName $commandName -parameter $parameter -commandParameters $commandParameters -helpParameters $helpParameters

  Context 'parameters' {
    # Pester 5 doesn't allow outside variables to leak into the `It` block scope
    # anymore. Until the Pester project has a supported workflow for this, the
    # workaround is to inject the data the block needs via a single test case.
    It 'has correct parameters' -TestCases @{command = $command} {
      $command.Parameters['loglevel'] | Should -Be $true
      $command.Parameters['modulepath'] | Should -Be $true
      $command.Parameters['project'] | Should -Be $true
      $command.Parameters['configfile'] | Should -Be $true
    }
  }

  Context 'help' {
    It 'should not be auto-generated' -TestCases @{help = $help} {
      $help.Synopsis | Should -Not -BeNullOrEmpty
      $help.Synopsis | Should -Not -BeLike '*`[`<CommonParameters`>`]*'
    }

    # Should be a description for every function
    It 'gets description' -TestCases @{help = $help} {
      $help.Description | Should -Not -BeNullOrEmpty
    }

    # Should be at least one link
    It 'gets relatedLinks' -TestCases @{help = $help} {
      ($help.relatedLinks | Select-Object -First 1).navigationLink | Should -Not -BeNullOrEmpty
    }

    # My guess is that someday soon, creating a hashtable array in a before block
    # and passing it to the -TestCases parameter will generate the tests you want.
    # For now, the array is out of scope when the file is parsed, so if you don't
    # foreach() loop like this, you don't get any tests. But you still have to inject
    # the data into each test. The Pester project is aware of this limitation
    # and would like to fix it, so some day this loop will go away.
    foreach($case in $helpCases) {
      # Should be a description for every parameter
      It 'gets help for parameter: <parameterName>' -TestCases $case {
        $parameterHelp.Description.Text | Should -Not -BeNullOrEmpty
      }

      # Required value in Help should match IsMandatory property of parameter
      It 'help for <parametername> has correct Mandatory value' -TestCases $case {
        $parameterHelp.Required | Should -Be $commandSaysisMandatory.toString()
      }

      # Parameter type in Help should match code
      It 'help has correct parameter type for <parameterName>' -TestCases $case {
        # To avoid calling Trim method on a null object.
        $helpType = if ($parameterHelp.parameterValue) { $parameterHelp.parameterValue.Trim() }
        $helpType | Should -Be $paramTypeName
      }
    }
  }
}

Describe "Register-BoltPuppetfileTypes" {
  $commandName       = 'Register-BoltPuppetfileTypes'
  $command           = Get-Command $commandName
  $help              = Get-Help -Name $commandName
  $CommonParameters  = Get-CommonParameters
  $commandParameters = Get-BoltCommandParameters -command $command -common $CommonParameters
  $helpParameters    = Get-BoltCommandHelpParameters -help $help -common $CommonParameters
  $helpCases         = Get-HelpCases -commandName $commandName -parameter $parameter -commandParameters $commandParameters -helpParameters $helpParameters

  Context 'parameters' {
    # Pester 5 doesn't allow outside variables to leak into the `It` block scope
    # anymore. Until the Pester project has a supported workflow for this, the
    # workaround is to inject the data the block needs via a single test case.
    It 'has correct parameters' -TestCases @{command = $command} {
      $command.Parameters['loglevel'] | Should -Be $true
      $command.Parameters['modulepath'] | Should -Be $true
      $command.Parameters['project'] | Should -Be $true
      $command.Parameters['configfile'] | Should -Be $true
    }
  }

  Context 'help' {
    It 'should not be auto-generated' -TestCases @{help = $help} {
      $help.Synopsis | Should -Not -BeNullOrEmpty
      $help.Synopsis | Should -Not -BeLike '*`[`<CommonParameters`>`]*'
    }

    # Should be a description for every function
    It 'gets description' -TestCases @{help = $help} {
      $help.Description | Should -Not -BeNullOrEmpty
    }

    # Should be at least one link
    It 'gets relatedLinks' -TestCases @{help = $help} {
      ($help.relatedLinks | Select-Object -First 1).navigationLink | Should -Not -BeNullOrEmpty
    }

    # My guess is that someday soon, creating a hashtable array in a before block
    # and passing it to the -TestCases parameter will generate the tests you want.
    # For now, the array is out of scope when the file is parsed, so if you don't
    # foreach() loop like this, you don't get any tests. But you still have to inject
    # the data into each test. The Pester project is aware of this limitation
    # and would like to fix it, so some day this loop will go away.
    foreach($case in $helpCases) {
      # Should be a description for every parameter
      It 'gets help for parameter: <parameterName>' -TestCases $case {
        $parameterHelp.Description.Text | Should -Not -BeNullOrEmpty
      }

      # Required value in Help should match IsMandatory property of parameter
      It 'help for <parametername> has correct Mandatory value' -TestCases $case {
        $parameterHelp.Required | Should -Be $commandSaysisMandatory.toString()
      }

      # Parameter type in Help should match code
      It 'help has correct parameter type for <parameterName>' -TestCases $case {
        # To avoid calling Trim method on a null object.
        $helpType = if ($parameterHelp.parameterValue) { $parameterHelp.parameterValue.Trim() }
        $helpType | Should -Be $paramTypeName
      }
    }
  }
}

Describe "Protect-BoltSecret" {
  $commandName       = 'Protect-BoltSecret'
  $command           = Get-Command $commandName
  $help              = Get-Help -Name $commandName
  $CommonParameters  = Get-CommonParameters
  $commandParameters = Get-BoltCommandParameters -command $command -common $CommonParameters
  $helpParameters    = Get-BoltCommandHelpParameters -help $help -common $CommonParameters
  $helpCases         = Get-HelpCases -commandName $commandName -parameter $parameter -commandParameters $commandParameters -helpParameters $helpParameters

  Context 'parameters' {
    # Pester 5 doesn't allow outside variables to leak into the `It` block scope
    # anymore. Until the Pester project has a supported workflow for this, the
    # workaround is to inject the data the block needs via a single test case.
    It 'has correct parameters' -TestCases @{command = $command} {
      $command.Parameters['text'] | Should -Be $true
      $command.Parameters['loglevel'] | Should -Be $true
      $command.Parameters['modulepath'] | Should -Be $true
      $command.Parameters['project'] | Should -Be $true
      $command.Parameters['configfile'] | Should -Be $true
      $command.Parameters['plugin'] | Should -Be $true
    }
    It 'has a primary parameter' -TestCases @{command = $command} {
      $command.Parameters['text'] | Should -Be $true
      $command.Parameters['text'].ParameterSets.Values.IsMandatory | Should -Be $true
    }
  }

  Context 'help' {
    It 'should not be auto-generated' -TestCases @{help = $help} {
      $help.Synopsis | Should -Not -BeNullOrEmpty
      $help.Synopsis | Should -Not -BeLike '*`[`<CommonParameters`>`]*'
    }

    # Should be a description for every function
    It 'gets description' -TestCases @{help = $help} {
      $help.Description | Should -Not -BeNullOrEmpty
    }

    # Should be at least one link
    It 'gets relatedLinks' -TestCases @{help = $help} {
      ($help.relatedLinks | Select-Object -First 1).navigationLink | Should -Not -BeNullOrEmpty
    }

    # My guess is that someday soon, creating a hashtable array in a before block
    # and passing it to the -TestCases parameter will generate the tests you want.
    # For now, the array is out of scope when the file is parsed, so if you don't
    # foreach() loop like this, you don't get any tests. But you still have to inject
    # the data into each test. The Pester project is aware of this limitation
    # and would like to fix it, so some day this loop will go away.
    foreach($case in $helpCases) {
      # Should be a description for every parameter
      It 'gets help for parameter: <parameterName>' -TestCases $case {
        $parameterHelp.Description.Text | Should -Not -BeNullOrEmpty
      }

      # Required value in Help should match IsMandatory property of parameter
      It 'help for <parametername> has correct Mandatory value' -TestCases $case {
        $parameterHelp.Required | Should -Be $commandSaysisMandatory.toString()
      }

      # Parameter type in Help should match code
      It 'help has correct parameter type for <parameterName>' -TestCases $case {
        # To avoid calling Trim method on a null object.
        $helpType = if ($parameterHelp.parameterValue) { $parameterHelp.parameterValue.Trim() }
        $helpType | Should -Be $paramTypeName
      }
    }
  }
}

Describe "Unprotect-BoltSecret" {
  $commandName       = 'Unprotect-BoltSecret'
  $command           = Get-Command $commandName
  $help              = Get-Help -Name $commandName
  $CommonParameters  = Get-CommonParameters
  $commandParameters = Get-BoltCommandParameters -command $command -common $CommonParameters
  $helpParameters    = Get-BoltCommandHelpParameters -help $help -common $CommonParameters
  $helpCases         = Get-HelpCases -commandName $commandName -parameter $parameter -commandParameters $commandParameters -helpParameters $helpParameters

  Context 'parameters' {
    # Pester 5 doesn't allow outside variables to leak into the `It` block scope
    # anymore. Until the Pester project has a supported workflow for this, the
    # workaround is to inject the data the block needs via a single test case.
    It 'has correct parameters' -TestCases @{command = $command} {
      $command.Parameters['text'] | Should -Be $true
      $command.Parameters['loglevel'] | Should -Be $true
      $command.Parameters['modulepath'] | Should -Be $true
      $command.Parameters['project'] | Should -Be $true
      $command.Parameters['configfile'] | Should -Be $true
      $command.Parameters['plugin'] | Should -Be $true
    }
    It 'has a primary parameter' -TestCases @{command = $command} {
      $command.Parameters['text'] | Should -Be $true
      $command.Parameters['text'].ParameterSets.Values.IsMandatory | Should -Be $true
    }
  }

  Context 'help' {
    It 'should not be auto-generated' -TestCases @{help = $help} {
      $help.Synopsis | Should -Not -BeNullOrEmpty
      $help.Synopsis | Should -Not -BeLike '*`[`<CommonParameters`>`]*'
    }

    # Should be a description for every function
    It 'gets description' -TestCases @{help = $help} {
      $help.Description | Should -Not -BeNullOrEmpty
    }

    # Should be at least one link
    It 'gets relatedLinks' -TestCases @{help = $help} {
      ($help.relatedLinks | Select-Object -First 1).navigationLink | Should -Not -BeNullOrEmpty
    }

    # My guess is that someday soon, creating a hashtable array in a before block
    # and passing it to the -TestCases parameter will generate the tests you want.
    # For now, the array is out of scope when the file is parsed, so if you don't
    # foreach() loop like this, you don't get any tests. But you still have to inject
    # the data into each test. The Pester project is aware of this limitation
    # and would like to fix it, so some day this loop will go away.
    foreach($case in $helpCases) {
      # Should be a description for every parameter
      It 'gets help for parameter: <parameterName>' -TestCases $case {
        $parameterHelp.Description.Text | Should -Not -BeNullOrEmpty
      }

      # Required value in Help should match IsMandatory property of parameter
      It 'help for <parametername> has correct Mandatory value' -TestCases $case {
        $parameterHelp.Required | Should -Be $commandSaysisMandatory.toString()
      }

      # Parameter type in Help should match code
      It 'help has correct parameter type for <parameterName>' -TestCases $case {
        # To avoid calling Trim method on a null object.
        $helpType = if ($parameterHelp.parameterValue) { $parameterHelp.parameterValue.Trim() }
        $helpType | Should -Be $paramTypeName
      }
    }
  }
}

Describe "New-BoltSecretKey" {
  $commandName       = 'New-BoltSecretKey'
  $command           = Get-Command $commandName
  $help              = Get-Help -Name $commandName
  $CommonParameters  = Get-CommonParameters
  $commandParameters = Get-BoltCommandParameters -command $command -common $CommonParameters
  $helpParameters    = Get-BoltCommandHelpParameters -help $help -common $CommonParameters
  $helpCases         = Get-HelpCases -commandName $commandName -parameter $parameter -commandParameters $commandParameters -helpParameters $helpParameters

  Context 'parameters' {
    # Pester 5 doesn't allow outside variables to leak into the `It` block scope
    # anymore. Until the Pester project has a supported workflow for this, the
    # workaround is to inject the data the block needs via a single test case.
    It 'has correct parameters' -TestCases @{command = $command} {
      $command.Parameters['text'] | Should -Be $true
      $command.Parameters['loglevel'] | Should -Be $true
      $command.Parameters['modulepath'] | Should -Be $true
      $command.Parameters['project'] | Should -Be $true
      $command.Parameters['configfile'] | Should -Be $true
      $command.Parameters['plugin'] | Should -Be $true
      $command.Parameters['force'] | Should -Be $true
    }
    It 'has a primary parameter' -TestCases @{command = $command} {
      $command.Parameters['text'] | Should -Be $true
      $command.Parameters['text'].ParameterSets.Values.IsMandatory | Should -Be $true
    }
  }

  Context 'help' {
    It 'should not be auto-generated' -TestCases @{help = $help} {
      $help.Synopsis | Should -Not -BeNullOrEmpty
      $help.Synopsis | Should -Not -BeLike '*`[`<CommonParameters`>`]*'
    }

    # Should be a description for every function
    It 'gets description' -TestCases @{help = $help} {
      $help.Description | Should -Not -BeNullOrEmpty
    }

    # Should be at least one link
    It 'gets relatedLinks' -TestCases @{help = $help} {
      ($help.relatedLinks | Select-Object -First 1).navigationLink | Should -Not -BeNullOrEmpty
    }

    # My guess is that someday soon, creating a hashtable array in a before block
    # and passing it to the -TestCases parameter will generate the tests you want.
    # For now, the array is out of scope when the file is parsed, so if you don't
    # foreach() loop like this, you don't get any tests. But you still have to inject
    # the data into each test. The Pester project is aware of this limitation
    # and would like to fix it, so some day this loop will go away.
    foreach($case in $helpCases) {
      # Should be a description for every parameter
      It 'gets help for parameter: <parameterName>' -TestCases $case {
        $parameterHelp.Description.Text | Should -Not -BeNullOrEmpty
      }

      # Required value in Help should match IsMandatory property of parameter
      It 'help for <parametername> has correct Mandatory value' -TestCases $case {
        $parameterHelp.Required | Should -Be $commandSaysisMandatory.toString()
      }

      # Parameter type in Help should match code
      It 'help has correct parameter type for <parameterName>' -TestCases $case {
        # To avoid calling Trim method on a null object.
        $helpType = if ($parameterHelp.parameterValue) { $parameterHelp.parameterValue.Trim() }
        $helpType | Should -Be $paramTypeName
      }
    }
  }
}

Describe "Get-BoltInventory" {
  $commandName       = 'Get-BoltInventory'
  $command           = Get-Command $commandName
  $help              = Get-Help -Name $commandName
  $CommonParameters  = Get-CommonParameters
  $commandParameters = Get-BoltCommandParameters -command $command -common $CommonParameters
  $helpParameters    = Get-BoltCommandHelpParameters -help $help -common $CommonParameters
  $helpCases         = Get-HelpCases -commandName $commandName -parameter $parameter -commandParameters $commandParameters -helpParameters $helpParameters

  Context 'parameters' {
    # Pester 5 doesn't allow outside variables to leak into the `It` block scope
    # anymore. Until the Pester project has a supported workflow for this, the
    # workaround is to inject the data the block needs via a single test case.
    It 'has correct parameters' -TestCases @{command = $command} {
      $command.Parameters['targets'] | Should -Be $true
      $command.Parameters['query'] | Should -Be $true
      $command.Parameters['rerun'] | Should -Be $true
      $command.Parameters['description'] | Should -Be $true
      $command.Parameters['loglevel'] | Should -Be $true
      $command.Parameters['format'] | Should -Be $true
      $command.Parameters['inventoryfile'] | Should -Be $true
      $command.Parameters['boltdir'] | Should -Be $true
      $command.Parameters['configfile'] | Should -Be $true
      $command.Parameters['detail'] | Should -Be $true
    }
  }

  Context 'help' {
    It 'should not be auto-generated' -TestCases @{help = $help} {
      $help.Synopsis | Should -Not -BeNullOrEmpty
      $help.Synopsis | Should -Not -BeLike '*`[`<CommonParameters`>`]*'
    }

    # Should be a description for every function
    It 'gets description' -TestCases @{help = $help} {
      $help.Description | Should -Not -BeNullOrEmpty
    }

    # Should be at least one link
    It 'gets relatedLinks' -TestCases @{help = $help} {
      ($help.relatedLinks | Select-Object -First 1).navigationLink | Should -Not -BeNullOrEmpty
    }

    # My guess is that someday soon, creating a hashtable array in a before block
    # and passing it to the -TestCases parameter will generate the tests you want.
    # For now, the array is out of scope when the file is parsed, so if you don't
    # foreach() loop like this, you don't get any tests. But you still have to inject
    # the data into each test. The Pester project is aware of this limitation
    # and would like to fix it, so some day this loop will go away.
    foreach($case in $helpCases) {
      # Should be a description for every parameter
      It 'gets help for parameter: <parameterName>' -TestCases $case {
        $parameterHelp.Description.Text | Should -Not -BeNullOrEmpty
      }

      # Required value in Help should match IsMandatory property of parameter
      It 'help for <parametername> has correct Mandatory value' -TestCases $case {
        $parameterHelp.Required | Should -Be $commandSaysisMandatory.toString()
      }

      # Parameter type in Help should match code
      It 'help has correct parameter type for <parameterName>' -TestCases $case {
        # To avoid calling Trim method on a null object.
        $helpType = if ($parameterHelp.parameterValue) { $parameterHelp.parameterValue.Trim() }
        $helpType | Should -Be $paramTypeName
      }
    }
  }
}

Describe "Get-BoltGroup" {
  $commandName       = 'Get-BoltGroup'
  $command           = Get-Command $commandName
  $help              = Get-Help -Name $commandName
  $CommonParameters  = Get-CommonParameters
  $commandParameters = Get-BoltCommandParameters -command $command -common $CommonParameters
  $helpParameters    = Get-BoltCommandHelpParameters -help $help -common $CommonParameters
  $helpCases         = Get-HelpCases -commandName $commandName -parameter $parameter -commandParameters $commandParameters -helpParameters $helpParameters

  Context 'parameters' {
    # Pester 5 doesn't allow outside variables to leak into the `It` block scope
    # anymore. Until the Pester project has a supported workflow for this, the
    # workaround is to inject the data the block needs via a single test case.
    It 'has correct parameters' -TestCases @{command = $command} {
      $command.Parameters['loglevel'] | Should -Be $true
      $command.Parameters['format'] | Should -Be $true
      $command.Parameters['inventoryfile'] | Should -Be $true
      $command.Parameters['boltdir'] | Should -Be $true
      $command.Parameters['configfile'] | Should -Be $true
    }
  }

  Context 'help' {
    It 'should not be auto-generated' -TestCases @{help = $help} {
      $help.Synopsis | Should -Not -BeNullOrEmpty
      $help.Synopsis | Should -Not -BeLike '*`[`<CommonParameters`>`]*'
    }

    # Should be a description for every function
    It 'gets description' -TestCases @{help = $help} {
      $help.Description | Should -Not -BeNullOrEmpty
    }

    # Should be at least one link
    It 'gets relatedLinks' -TestCases @{help = $help} {
      ($help.relatedLinks | Select-Object -First 1).navigationLink | Should -Not -BeNullOrEmpty
    }

    # My guess is that someday soon, creating a hashtable array in a before block
    # and passing it to the -TestCases parameter will generate the tests you want.
    # For now, the array is out of scope when the file is parsed, so if you don't
    # foreach() loop like this, you don't get any tests. But you still have to inject
    # the data into each test. The Pester project is aware of this limitation
    # and would like to fix it, so some day this loop will go away.
    foreach($case in $helpCases) {
      # Should be a description for every parameter
      It 'gets help for parameter: <parameterName>' -TestCases $case {
        $parameterHelp.Description.Text | Should -Not -BeNullOrEmpty
      }

      # Required value in Help should match IsMandatory property of parameter
      It 'help for <parametername> has correct Mandatory value' -TestCases $case {
        $parameterHelp.Required | Should -Be $commandSaysisMandatory.toString()
      }

      # Parameter type in Help should match code
      It 'help has correct parameter type for <parameterName>' -TestCases $case {
        # To avoid calling Trim method on a null object.
        $helpType = if ($parameterHelp.parameterValue) { $parameterHelp.parameterValue.Trim() }
        $helpType | Should -Be $paramTypeName
      }
    }
  }
}

Describe "New-BoltProject" {
  $commandName       = 'New-BoltProject'
  $command           = Get-Command $commandName
  $help              = Get-Help -Name $commandName
  $CommonParameters  = Get-CommonParameters
  $commandParameters = Get-BoltCommandParameters -command $command -common $CommonParameters
  $helpParameters    = Get-BoltCommandHelpParameters -help $help -common $CommonParameters
  $helpCases         = Get-HelpCases -commandName $commandName -parameter $parameter -commandParameters $commandParameters -helpParameters $helpParameters

  Context 'parameters' {
    # Pester 5 doesn't allow outside variables to leak into the `It` block scope
    # anymore. Until the Pester project has a supported workflow for this, the
    # workaround is to inject the data the block needs via a single test case.
    It 'has correct parameters' -TestCases @{command = $command} {
      $command.Parameters['directory'] | Should -Be $true
      $command.Parameters['loglevel'] | Should -Be $true
      $command.Parameters['modules'] | Should -Be $true
    }
  }

  Context 'help' {
    It 'should not be auto-generated' -TestCases @{help = $help} {
      $help.Synopsis | Should -Not -BeNullOrEmpty
      $help.Synopsis | Should -Not -BeLike '*`[`<CommonParameters`>`]*'
    }

    # Should be a description for every function
    It 'gets description' -TestCases @{help = $help} {
      $help.Description | Should -Not -BeNullOrEmpty
    }

    # Should be at least one link
    It 'gets relatedLinks' -TestCases @{help = $help} {
      ($help.relatedLinks | Select-Object -First 1).navigationLink | Should -Not -BeNullOrEmpty
    }

    # My guess is that someday soon, creating a hashtable array in a before block
    # and passing it to the -TestCases parameter will generate the tests you want.
    # For now, the array is out of scope when the file is parsed, so if you don't
    # foreach() loop like this, you don't get any tests. But you still have to inject
    # the data into each test. The Pester project is aware of this limitation
    # and would like to fix it, so some day this loop will go away.
    foreach($case in $helpCases) {
      # Should be a description for every parameter
      It 'gets help for parameter: <parameterName>' -TestCases $case {
        $parameterHelp.Description.Text | Should -Not -BeNullOrEmpty
      }

      # Required value in Help should match IsMandatory property of parameter
      It 'help for <parametername> has correct Mandatory value' -TestCases $case {
        $parameterHelp.Required | Should -Be $commandSaysisMandatory.toString()
      }

      # Parameter type in Help should match code
      It 'help has correct parameter type for <parameterName>' -TestCases $case {
        # To avoid calling Trim method on a null object.
        $helpType = if ($parameterHelp.parameterValue) { $parameterHelp.parameterValue.Trim() }
        $helpType | Should -Be $paramTypeName
      }
    }
  }
}

Describe "Update-BoltProject" {
  $commandName       = 'Update-BoltProject'
  $command           = Get-Command $commandName
  $help              = Get-Help -Name $commandName
  $CommonParameters  = Get-CommonParameters
  $commandParameters = Get-BoltCommandParameters -command $command -common $CommonParameters
  $helpParameters    = Get-BoltCommandHelpParameters -help $help -common $CommonParameters
  $helpCases         = Get-HelpCases -commandName $commandName -parameter $parameter -commandParameters $commandParameters -helpParameters $helpParameters

  Context 'parameters' {
    # Pester 5 doesn't allow outside variables to leak into the `It` block scope
    # anymore. Until the Pester project has a supported workflow for this, the
    # workaround is to inject the data the block needs via a single test case.
    It 'has correct parameters' -TestCases @{command = $command} {
      $command.Parameters['directory'] | Should -Be $true
      $command.Parameters['loglevel'] | Should -Be $true
      $command.Parameters['inventoryfile'] | Should -Be $true
      $command.Parameters['boltdir'] | Should -Be $true
      $command.Parameters['configfile'] | Should -Be $true
    }
  }

  Context 'help' {
    It 'should not be auto-generated' -TestCases @{help = $help} {
      $help.Synopsis | Should -Not -BeNullOrEmpty
      $help.Synopsis | Should -Not -BeLike '*`[`<CommonParameters`>`]*'
    }

    # Should be a description for every function
    It 'gets description' -TestCases @{help = $help} {
      $help.Description | Should -Not -BeNullOrEmpty
    }

    # Should be at least one link
    It 'gets relatedLinks' -TestCases @{help = $help} {
      ($help.relatedLinks | Select-Object -First 1).navigationLink | Should -Not -BeNullOrEmpty
    }

    # My guess is that someday soon, creating a hashtable array in a before block
    # and passing it to the -TestCases parameter will generate the tests you want.
    # For now, the array is out of scope when the file is parsed, so if you don't
    # foreach() loop like this, you don't get any tests. But you still have to inject
    # the data into each test. The Pester project is aware of this limitation
    # and would like to fix it, so some day this loop will go away.
    foreach($case in $helpCases) {
      # Should be a description for every parameter
      It 'gets help for parameter: <parameterName>' -TestCases $case {
        $parameterHelp.Description.Text | Should -Not -BeNullOrEmpty
      }

      # Required value in Help should match IsMandatory property of parameter
      It 'help for <parametername> has correct Mandatory value' -TestCases $case {
        $parameterHelp.Required | Should -Be $commandSaysisMandatory.toString()
      }

      # Parameter type in Help should match code
      It 'help has correct parameter type for <parameterName>' -TestCases $case {
        # To avoid calling Trim method on a null object.
        $helpType = if ($parameterHelp.parameterValue) { $parameterHelp.parameterValue.Trim() }
        $helpType | Should -Be $paramTypeName
      }
    }
  }
}

Describe "Invoke-BoltApply" {
  $commandName       = 'Invoke-BoltApply'
  $command           = Get-Command $commandName
  $help              = Get-Help -Name $commandName
  $CommonParameters  = Get-CommonParameters
  $commandParameters = Get-BoltCommandParameters -command $command -common $CommonParameters
  $helpParameters    = Get-BoltCommandHelpParameters -help $help -common $CommonParameters
  $helpCases         = Get-HelpCases -commandName $commandName -parameter $parameter -commandParameters $commandParameters -helpParameters $helpParameters

  Context 'parameters' {
    # Pester 5 doesn't allow outside variables to leak into the `It` block scope
    # anymore. Until the Pester project has a supported workflow for this, the
    # workaround is to inject the data the block needs via a single test case.
    It 'has correct parameters' -TestCases @{command = $command} {
      $command.Parameters['manifest'].Attributes.Mandatory | Should -Be $true
      $command.Parameters['targets'] | Should -Be $true
      $command.Parameters['query'] | Should -Be $true
      $command.Parameters['rerun'] | Should -Be $true
      $command.Parameters['description'] | Should -Be $true
      $command.Parameters['user'] | Should -Be $true
      $command.Parameters['password'] | Should -Be $true
      $command.Parameters['passwordprompt'] | Should -Be $true
      $command.Parameters['privatekey'] | Should -Be $true
      $command.Parameters['hostkeycheck'] | Should -Be $true
      $command.Parameters['ssl'] | Should -Be $true
      $command.Parameters['sslverify'] | Should -Be $true
      $command.Parameters['runas'] | Should -Be $true
      $command.Parameters['sudopassword'] | Should -Be $true
      $command.Parameters['sudopasswordprompt'] | Should -Be $true
      $command.Parameters['sudoexecutable'] | Should -Be $true
      $command.Parameters['concurrency'] | Should -Be $true
      $command.Parameters['inventoryfile'] | Should -Be $true
      $command.Parameters['savererun'] | Should -Be $true
      $command.Parameters['cleanup'] | Should -Be $true
      $command.Parameters['modulepath'] | Should -Be $true
      $command.Parameters['project'] | Should -Be $true
      $command.Parameters['configfile'] | Should -Be $true
      $command.Parameters['transport'] | Should -Be $true
      $command.Parameters['connecttimeout'] | Should -Be $true
      $command.Parameters['tty'] | Should -Be $true
      $command.Parameters['nativessh'] | Should -Be $true
      $command.Parameters['sshcommand'] | Should -Be $true
      $command.Parameters['copycommand'] | Should -Be $true
      $command.Parameters['format'] | Should -Be $true
      $command.Parameters['color'] | Should -Be $true
      $command.Parameters['trace'] | Should -Be $true
      $command.Parameters['loglevel'] | Should -Be $true
      $command.Parameters['noop'] | Should -Be $true
      $command.Parameters['execute'].Attributes.Mandatory | Should -Be $true
      $command.Parameters['compileconcurrency'] | Should -Be $true
      $command.Parameters['hieraconfig'] | Should -Be $true
    }
    It 'has a primary parameter' -TestCases @{command = $command} {
      $command.Parameters['manifest'] | Should -Be $true
      $command.Parameters['manifest'].ParameterSets.Values.IsMandatory | Should -Be $true
    }
    It 'has a primary parameter' -TestCases @{command = $command} {
      $command.Parameters['execute'] | Should -Be $true
      $command.Parameters['execute'].ParameterSets.Values.IsMandatory | Should -Be $true
    }
  }

  Context 'help' {
    It 'should not be auto-generated' -TestCases @{help = $help} {
      $help.Synopsis | Should -Not -BeNullOrEmpty
      $help.Synopsis | Should -Not -BeLike '*`[`<CommonParameters`>`]*'
    }

    # Should be a description for every function
    It 'gets description' -TestCases @{help = $help} {
      $help.Description | Should -Not -BeNullOrEmpty
    }

    # Should be at least one link
    It 'gets relatedLinks' -TestCases @{help = $help} {
      ($help.relatedLinks | Select-Object -First 1).navigationLink | Should -Not -BeNullOrEmpty
    }

    # My guess is that someday soon, creating a hashtable array in a before block
    # and passing it to the -TestCases parameter will generate the tests you want.
    # For now, the array is out of scope when the file is parsed, so if you don't
    # foreach() loop like this, you don't get any tests. But you still have to inject
    # the data into each test. The Pester project is aware of this limitation
    # and would like to fix it, so some day this loop will go away.
    foreach($case in $helpCases) {
      # Should be a description for every parameter
      It 'gets help for parameter: <parameterName>' -TestCases $case {
        $parameterHelp.Description.Text | Should -Not -BeNullOrEmpty
      }

      # Required value in Help should match IsMandatory property of parameter
      It 'help for <parametername> has correct Mandatory value' -TestCases $case {
        $parameterHelp.Required | Should -Be $commandSaysisMandatory.toString()
      }

      # Parameter type in Help should match code
      It 'help has correct parameter type for <parameterName>' -TestCases $case {
        # To avoid calling Trim method on a null object.
        $helpType = if ($parameterHelp.parameterValue) { $parameterHelp.parameterValue.Trim() }
        $helpType | Should -Be $paramTypeName
      }
    }
  }
}

