using AimPark.API.DTOs;
using AimPark.API.Entities;
using AimPark.API.Enums;
using AimPark.API.Helpers;
using AimPark.API.Interfaces;
using Microsoft.AspNetCore.Mvc;

namespace AimPark.API.Services
{
    /// <summary>
    /// Vehicles added after registration is finished.
    /// </summary>
    /// <remarks>
    /// One RFID card covers every vehicle its holder registers, so a user who buys a
    /// second vehicle adds it here rather than repeating signup. The first vehicle
    /// still comes through <see cref="RegistrationService"/>, which keeps the signup
    /// flow a straight line.
    /// </remarks>
    public class VehicleService : IVehicleService
    {
        private readonly IRepository<User> _users;
        private readonly IRepository<Vehicle> _vehicles;

        public VehicleService(IRepository<User> users, IRepository<Vehicle> vehicles)
        {
            _users = users;
            _vehicles = vehicles;
        }

        public async Task<ActionResult<List<VehicleDetailResponse>>> GetMyVehiclesAsync(Guid userId, CancellationToken ct)
        {
            var vehicles = await _vehicles.GetAllAsync(v => v.UserId == userId, ct);

            return new OkObjectResult(vehicles
                .OrderBy(v => v.CreatedAt)
                .Select(Map)
                .ToList());
        }

        public async Task<ActionResult<object>> AddVehicleAsync(VehicleDTO dto, Guid userId, CancellationToken ct)
        {
            var user = await _users.FindAsync(u => u.Id == userId, ct);
            if (user is null)
                return new NotFoundObjectResult(new { message = "User not found." });

            // Only an approved account may add vehicles. A pending applicant adding a
            // second vehicle would sidestep the review their first one is waiting for.
            if (user.AccountStatus != AccountStatus.Active)
                return new BadRequestObjectResult(new { message = "Your account must be approved before adding a vehicle." });

            // Brand and model are deliberately absent. Nothing reads them — the gate
            // matches on the plate and allocation on the type — so requiring them
            // only makes the form longer.
            if (ValidationHelper.HasEmptyFields(dto.PlateNumber, dto.VehicleType, dto.Color))
                return new BadRequestObjectResult(new { message = "Plate number, vehicle type and colour are required." });

            if (!Enum.TryParse<VehicleType>(dto.VehicleType, true, out var vehicleType))
                return new BadRequestObjectResult(new { message = "Invalid vehicle type." });

            var plate = IdentifierNormalizer.NormalizePlate(dto.PlateNumber);
            if (plate.Length is < 4 or > 10)
                return new BadRequestObjectResult(new { message = "Plate number looks invalid." });

            // The plate is globally unique: ALPR looks one up and must get exactly one
            // vehicle back. Answered explicitly so the caller sees a message rather
            // than a database constraint error.
            if (await _vehicles.ExistsAsync(v => v.PlateNumber == plate, ct))
                return new BadRequestObjectResult(new { message = "That plate number is already registered." });

            var vehicle = new Vehicle
            {
                PlateNumber = plate,
                VehicleType = vehicleType,
                Brand = dto.Brand.Trim(),
                Model = dto.Model.Trim(),
                Color = dto.Color.Trim(),
                UserId = userId
            };

            await _vehicles.AddAsync(vehicle, ct);
            await _vehicles.SaveAsync(ct);

            return new OkObjectResult(new
            {
                message = "Vehicle added.",
                vehicle = Map(vehicle)
            });
        }

        private static VehicleDetailResponse Map(Vehicle v) => new()
        {
            Id = v.Id,
            PlateNumber = v.PlateNumber,
            VehicleType = v.VehicleType.ToString(),
            Brand = v.Brand,
            Model = v.Model,
            Color = v.Color,
            RegistrationValidThrough = v.RegistrationValidThrough,
            CreatedAt = v.CreatedAt
        };
    }
}
