#!/bin/bash

# Network Interface Manager Startup Script

echo "🌐 Network Interface Manager"
echo "=================================="

# Check if Python 3 is installed
if ! command -v python3 &> /dev/null; then
    echo "❌ Python 3 is not installed. Please install Python 3 first."
    exit 1
fi

# Check if pip is installed
if ! command -v pip3 &> /dev/null; then
    echo "❌ pip3 is not installed. Please install pip3 first."
    exit 1
fi

# Create virtual environment if it doesn't exist
if [ ! -d "venv" ]; then
    echo "📦 Creating virtual environment..."
    python3 -m venv venv
fi

# Activate virtual environment
echo "🔧 Activating virtual environment..."
source venv/bin/activate

# Install dependencies
echo "📥 Installing dependencies..."
pip install -r requirements.txt

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    echo "⚠️  Running as root - all network operations will be available"
else
    echo "⚠️  Not running as root - some operations may require sudo"
    echo "   For full functionality, run with: sudo ./start.sh"
fi

echo "🚀 Starting Network Interface Manager..."
echo "   Access the web interface at: http://localhost:5020"
echo "   Press Ctrl+C to stop the server"
echo "=================================="

# Start the application
python3 app.py