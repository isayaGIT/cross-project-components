FROM python:3.13-slim
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1 PORT=8080 ASSET_APP_ID=sample-app ASSET_DATA_DIR=/data INTERACTIVE_ASSET_SCHEMA_DIR=/app/schemas ASSET_SERVER_PROTOCOL_DIR=/app/asset-server-protocol
WORKDIR /app
COPY Infrastructure/AssetServer/sample/server/requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r /app/requirements.txt
COPY Infrastructure/AssetServer/sample/server/server.py /app/server.py
COPY Infrastructure/AssetServer/sample/server/index.html /app/index.html
COPY Protocols/InteractiveAssets/Schemas /app/schemas
COPY Infrastructure/AssetServer/Protocols /app/asset-server-protocol
RUN mkdir -p /data/files && chown -R nobody:nogroup /app /data
USER nobody
EXPOSE 8080
CMD ["python", "/app/server.py"]
