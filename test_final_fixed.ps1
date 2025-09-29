# test_final_fixed.ps1
Write-Host "Testing BrokerX+ API (Fixed Version)..." -ForegroundColor Green

# Test registration
Write-Host "`n1. Testing registration..." -ForegroundColor Yellow
$timestamp = Get-Date -Format "yyyyMMddHHmmss"
$email = "fixedtest_$timestamp@example.com"

$body = @{
    client = @{
        email = $email
        first_name = "Fixed"
        last_name = "Test"
        date_of_birth = "1990-01-01"
        password = "password123"
    }
} | ConvertTo-Json

try {
    $response = Invoke-WebRequest -Uri "http://localhost:3000/api/v1/clients/register" -Method Post -Body $body -ContentType "application/json"
    Write-Host "SUCCESS - Status: $($response.StatusCode)" -ForegroundColor Green
    
    # Parse the JSON response
    $jsonResponse = $response.Content | ConvertFrom-Json
    Write-Host "Response JSON:" -ForegroundColor Cyan
    Write-Host "  Success: $($jsonResponse.success)" -ForegroundColor White
    Write-Host "  Message: $($jsonResponse.message)" -ForegroundColor White
    
    if ($jsonResponse.client) {
        Write-Host "  Client Details:" -ForegroundColor Cyan
        Write-Host "    ID: $($jsonResponse.client.id)" -ForegroundColor White
        Write-Host "    Email: $($jsonResponse.client.email)" -ForegroundColor White
        Write-Host "    Full Name: $($jsonResponse.client.full_name)" -ForegroundColor White
        Write-Host "    Status: $($jsonResponse.client.status)" -ForegroundColor White
    }
    # Capture verification token if present
    $verificationToken = $null
    if ($jsonResponse.verification_token) {
        $verificationToken = $jsonResponse.verification_token
        Write-Host "  Verification Token: $verificationToken" -ForegroundColor White
    }
    $global:testEmail = $email
} catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    if ($_.Exception.Response) {
        Write-Host "Status Code: $($_.Exception.Response.StatusCode)" -ForegroundColor Red
        try {
            $stream = $_.Exception.Response.GetResponseStream()
            $reader = New-Object System.IO.StreamReader($stream)
            $responseBody = $reader.ReadToEnd()
            Write-Host "Response: $responseBody" -ForegroundColor Red
        } catch {
            Write-Host "Could not read response body" -ForegroundColor Red
        }
    }
    exit
}

# Test authentication
if ($global:testEmail) {
    # If we have a verification token, call the verify endpoint first
    if ($verificationToken) {
        Write-Host "`n1.5. Verifying account..." -ForegroundColor Yellow
        try {
            $verifyUri = "http://localhost:3000/api/v1/clients/verify?token=$verificationToken"
            $verifyResponse = Invoke-WebRequest -Uri $verifyUri -Method Get
            Write-Host "Verification response status: $($verifyResponse.StatusCode)" -ForegroundColor Green
            $verifyJson = $verifyResponse.Content | ConvertFrom-Json
            Write-Host "Verification: $($verifyJson.message)" -ForegroundColor White
        } catch {
            Write-Host "Verification failed: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    Write-Host "`n2. Testing authentication..." -ForegroundColor Yellow
    $body = @{
        email = $global:testEmail
        password = "password123"
    } | ConvertTo-Json

    try {
        $response = Invoke-WebRequest -Uri "http://localhost:3000/api/v1/auth/login" -Method Post -Body $body -ContentType "application/json"
        Write-Host "SUCCESS - Status: $($response.StatusCode)" -ForegroundColor Green
        
        # Parse the JSON response
        $jsonResponse = $response.Content | ConvertFrom-Json
        Write-Host "Response JSON:" -ForegroundColor Cyan
        Write-Host "  Success: $($jsonResponse.success)" -ForegroundColor White
        
        if ($jsonResponse.token) {
            Write-Host "  Token: $($jsonResponse.token.Substring(0, [System.Math]::Min(20, $jsonResponse.token.Length)))..." -ForegroundColor White
        }
        
        if ($jsonResponse.client) {
            Write-Host "  Client Details:" -ForegroundColor Cyan
            Write-Host "    ID: $($jsonResponse.client.id)" -ForegroundColor White
            Write-Host "    Email: $($jsonResponse.client.email)" -ForegroundColor White
            Write-Host "    Full Name: $($jsonResponse.client.full_name)" -ForegroundColor White
        }
    } catch {
        Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
        if ($_.Exception.Response) {
            Write-Host "Status Code: $($_.Exception.Response.StatusCode)" -ForegroundColor Red
            try {
                $stream = $_.Exception.Response.GetResponseStream()
                $reader = New-Object System.IO.StreamReader($stream)
                $responseBody = $reader.ReadToEnd()
                Write-Host "Response: $responseBody" -ForegroundColor Red
            } catch {
                Write-Host "Could not read response body" -ForegroundColor Red
            }
        }
    }
}

Write-Host "`nTest completed!" -ForegroundColor Green