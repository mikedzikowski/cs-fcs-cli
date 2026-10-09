#!/usr/bin/env python3
"""
Vulnerable Flask application for security testing
Contains multiple security issues for FCS CLI to detect
"""

import os
import subprocess
import sqlite3
from flask import Flask, request, render_template_string

app = Flask(__name__)

# Hardcoded credentials (security risk)
DATABASE_PASSWORD = "admin123"
API_KEY = "sk-1234567890abcdef"
JWT_SECRET = "supersecret"

# Insecure configuration
app.config['DEBUG'] = True
app.config['SECRET_KEY'] = 'easy_to_guess'

@app.route('/')
def home():
    return """
    <h1>Vulnerable Test App</h1>
    <p>This app contains security vulnerabilities for testing purposes.</p>
    <form action="/search" method="GET">
        <input type="text" name="query" placeholder="Search...">
        <button type="submit">Search</button>
    </form>
    """

@app.route('/search')
def search():
    query = request.args.get('query', '')

    # SQL Injection vulnerability
    conn = sqlite3.connect('/tmp/app.db')
    cursor = conn.cursor()
    sql = f"SELECT * FROM users WHERE name LIKE '%{query}%'"
    cursor.execute(sql)
    results = cursor.fetchall()
    conn.close()

    # XSS vulnerability
    return render_template_string(f"""
    <h2>Search Results for: {query}</h2>
    <ul>
    {% for result in results %}
        <li>{{ result }}</li>
    {% endfor %}
    </ul>
    """, results=results)

@app.route('/exec')
def execute_command():
    # Command Injection vulnerability
    cmd = request.args.get('cmd', 'whoami')
    result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    return f"<pre>{result.stdout}</pre>"

@app.route('/file')
def read_file():
    # Path Traversal vulnerability
    filename = request.args.get('file', 'config.txt')
    try:
        with open(f"/app/{filename}", 'r') as f:
            content = f.read()
        return f"<pre>{content}</pre>"
    except FileNotFoundError:
        return "File not found"

@app.route('/admin')
def admin():
    # Weak authentication
    password = request.args.get('password', '')
    if password == 'admin':
        return f"""
        <h2>Admin Panel</h2>
        <p>Database Password: {DATABASE_PASSWORD}</p>
        <p>API Key: {API_KEY}</p>
        <p>JWT Secret: {JWT_SECRET}</p>
        """
    return "Access Denied"

if __name__ == '__main__':
    # Initialize database with sample data
    conn = sqlite3.connect('/tmp/app.db')
    cursor = conn.cursor()
    cursor.execute('''CREATE TABLE IF NOT EXISTS users
                     (id INTEGER PRIMARY KEY, name TEXT, email TEXT)''')
    cursor.execute("INSERT OR IGNORE INTO users VALUES (1, 'admin', 'admin@test.com')")
    cursor.execute("INSERT OR IGNORE INTO users VALUES (2, 'user', 'user@test.com')")
    conn.commit()
    conn.close()

    # Run on all interfaces (security risk)
    app.run(host='0.0.0.0', port=5000, debug=True)