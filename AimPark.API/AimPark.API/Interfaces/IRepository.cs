using System.Linq.Expressions;
namespace AimPark.API.Interfaces
{
    public interface IRepository<T> where T : class
    {
        Task<bool> ExistsAsync(Expression<Func<T, bool>> predicate, CancellationToken ct = default);
        Task<T?> FindAsync(Expression<Func<T, bool>> predicate, CancellationToken ct = default);
        Task<List<T>> GetAllAsync(Expression<Func<T, bool>>? predicate = null, CancellationToken ct = default);
        Task AddAsync(T entity, CancellationToken ct = default);       
        Task AddRangeAsync(IEnumerable<T> entities, CancellationToken ct = default);
        void Update(T entity);
        void Delete(T entity);
        Task SaveAsync(CancellationToken ct = default);
    }
}
