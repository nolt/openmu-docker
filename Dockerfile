FROM ubuntu:24.04 AS build

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y \
    dotnet-sdk-10.0 \
    git \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

WORKDIR /src
RUN git clone https://github.com/MUnique/OpenMU.git .

WORKDIR /src/src/Startup/
RUN dotnet build MUnique.OpenMU.Startup.csproj -o out -p:ci=true /property:GenerateFullPaths=true
RUN dotnet publish MUnique.OpenMU.Startup.csproj -c Release -o /opt/serwer -p:ci=true

FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y \
    dotnet-sdk-10.0 \
    libgssapi-krb5-2 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

COPY --from=build /opt/serwer /opt/serwer

RUN chown -R ubuntu:ubuntu /opt/serwer
USER ubuntu
WORKDIR /opt/serwer

ENTRYPOINT ["/bin/bash", "-c", "dotnet ./MUnique.OpenMU.Startup.dll -autostart -resolveIP:local"]
