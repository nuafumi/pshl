# Логгер HTTP-запросов на порту 1000
# Записывает в CSV лог: время запроса и IP адрес клиента из локальной сети
# После записи соединение сбрасывается

param (
    [int]$Port = 1000,
    [string]$LogPath = ".\http_requests_$(Get-Date -Format 'yyyyMMdd').csv"
)

try {
    # Создаем лог файл с заголовками, если его нет
    if (-not (Test-Path $LogPath)) {
        "Timestamp,ClientIP,LocalIP" | Out-File -FilePath $LogPath -Encoding UTF8
    }

    # Получаем локальный IP адрес
    $localIP = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -match '^(192\.168|10\.|172\.(1[6-9]|2[0-9]|3[0-1]))' } | Select-Object -First 1).IPAddress
    if (-not $localIP) {
        $localIP = "127.0.0.1"
        Write-Warning "Не удалось определить локальный IP адрес. Используется 127.0.0.1"
    }

    # Создаем TCP listener
    $listener = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Any, $Port)
    $listener.Start()
    
    Write-Host "Сервер запущен на порту $Port"
    Write-Host "Локальный IP: $localIP"
    Write-Host "Лог файл: $LogPath"
    Write-Host "Для остановки нажмите Ctrl+C"
    Write-Host "------------------------------"

    while ($true) {
        try {
            # Ждем входящее соединение
            $client = $listener.AcceptTcpClient()
            
            # Получаем информацию о клиенте
            $clientStream = $client.GetStream()
            $remoteEndpoint = $client.Client.RemoteEndPoint
            $clientIP = $remoteEndpoint.Address.ToString()
            
            # Получаем текущее время
            $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
            
            # Записываем в лог
            "$timestamp,$clientIP,$localIP" | Out-File -FilePath $LogPath -Append -Encoding UTF8
            
            Write-Host "[$timestamp] Запрос от: $clientIP"
            
            # Отправляем минимальный HTTP ответ для корректного завершения соединения
            $response = "HTTP/1.1 200 OK`r`nContent-Type: text/plain`r`nContent-Length: 0`r`nConnection: close`r`n`r`n"
            $buffer = [System.Text.Encoding]::UTF8.GetBytes($response)
            $clientStream.Write($buffer, 0, $buffer.Length)
            
            # Закрываем соединение
            $clientStream.Close()
            $client.Close()
            
        }
        catch {
            Write-Warning "Ошибка при обработке соединения: $_"
        }
    }
}
catch {
    Write-Error "Критическая ошибка: $_"
}
finally {
    # Очищаем ресурсы при завершении
    if ($listener) {
        $listener.Stop()
        Write-Host "Сервер остановлен"
    }
}
