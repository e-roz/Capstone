using AimPark.API.Interfaces;
using Microsoft.EntityFrameworkCore;
using System.Linq.Expressions;
using AimPark.API.Data;

namespace AimPark.API.Services
{
    public class Repository<T> : IRepository<T> where T : class
    {
        private readonly AppDbContext _db;
        private readonly DbSet<T> _set;

        public Repository(AppDbContext db)
        {
            _db = db;
            _set = db.Set<T>();
        }

        public async Task<bool> ExistsAsync(Expression<Func<T, bool>> predicate, CancellationToken ct = default)
            => await _set.AnyAsync(predicate, ct);

        public async Task<T?> FindAsync(Expression<Func<T, bool>> predicate, CancellationToken ct = default)
            => await _set.FirstOrDefaultAsync(predicate, ct); 

        public async Task<List<T>> GetAllAsync(Expression<Func<T, bool>>? predicate = null, CancellationToken ct = default)
            => predicate is null
                ? await _set.ToListAsync(ct)
                : await _set.Where(predicate).ToListAsync(ct);

        public async Task AddAsync(T entity, CancellationToken ct = default)
            => await _set.AddAsync(entity, ct);

        public async Task AddRangeAsync(IEnumerable<T> entities, CancellationToken ct = default)
            => await _set.AddRangeAsync(entities, ct);

        public void Update(T entity) => _set.Update(entity);

        public void Delete(T entity) => _set.Remove(entity);

        public async Task SaveAsync(CancellationToken ct = default)
            => await _db.SaveChangesAsync(ct);
    }
}
