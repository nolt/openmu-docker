FROM mcr.microsoft.com/dotnet/sdk:10.0-alpine AS build

RUN apk add --no-cache git ca-certificates

WORKDIR /src
RUN git clone https://github.com/MUnique/OpenMU.git .

WORKDIR /src/src/Startup/
RUN dotnet publish MUnique.OpenMU.Startup.csproj -c Release -o /opt/openmu-server -p:ci=true

FROM mcr.microsoft.com/dotnet/aspnet:10.0-alpine

# tzdata: TZ env resolves real zones (server time, e.g. Europe/Warsaw);
# icu-libs: full globalization; icu-data-full: locale data for every language -
# Alpine's icu-libs ships only English (icu-data-en), so cultures like "pl" are
# unknown and players get English texts (e.g. bot chat) even with a Polish
# account language; krb5-libs: Npgsql GSS (replaces Ubuntu's libgssapi-krb5-2).
# OpenMU's image handling is SixLabors.ImageSharp (managed), so no native
# graphics libraries are needed.
RUN apk add --no-cache tzdata icu-libs icu-data-full krb5-libs
ENV DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=false

COPY --from=build /opt/openmu-server /opt/openmu-server
RUN chown -R app:app /opt/openmu-server
WORKDIR /opt/openmu-server
USER app

ENTRYPOINT ["dotnet", "MUnique.OpenMU.Startup.dll", "-autostart"]
