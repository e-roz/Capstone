# Build and run the AimPark API.
# Lives at the repo root because Render builds from the repository root by default.

# ---- build stage ----
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src

# Restore first, as its own layer, so dependency downloads are cached and only
# re-run when the project file itself changes.
COPY AimPark.API/AimPark.API/AimPark.API.csproj AimPark.API/AimPark.API/
RUN dotnet restore AimPark.API/AimPark.API/AimPark.API.csproj

COPY AimPark.API/ AimPark.API/
RUN dotnet publish AimPark.API/AimPark.API/AimPark.API.csproj \
    -c Release \
    -o /app/publish \
    /p:UseAppHost=false

# ---- runtime stage ----
# The smaller aspnet image (no SDK) is all that's needed to run the published output.
FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS runtime
WORKDIR /app

COPY --from=build /app/publish .

# The host injects the real port via $PORT at runtime; Program.cs reads it.
# This is only a sensible default for running the image directly.
ENV ASPNETCORE_ENVIRONMENT=Production
EXPOSE 8080

ENTRYPOINT ["dotnet", "AimPark.API.dll"]
