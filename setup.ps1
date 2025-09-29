# setup.ps1
Write-Host "🚀 Setting up BrokerX+ on Windows..." -ForegroundColor Green

Write-Host "📦 Installing gems..." -ForegroundColor Yellow
bundle install

Write-Host "🗄️ Creating database..." -ForegroundColor Yellow
rails db:create

Write-Host "🔄 Running migrations..." -ForegroundColor Yellow
rails db:migrate

Write-Host "🧪 Setting up test database..." -ForegroundColor Yellow
$env:RAILS_ENV = "test"
rails db:create
rails db:migrate
$env:RAILS_ENV = "development"

Write-Host "✅ Setup completed successfully!" -ForegroundColor Green
Write-Host "🎯 Start the server with: rails server" -ForegroundColor Cyan