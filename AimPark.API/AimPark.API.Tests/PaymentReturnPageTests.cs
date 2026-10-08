using AimPark.API.Controllers;

namespace AimPark.API.Tests;

/// <summary>
/// The page a payer lands on after PayMongo. It is the way back into the app,
/// so what it links to matters more than how it looks.
/// </summary>
public class PaymentReturnPageTests
{
    private static string Page(string status, Guid? payment) =>
        new PaymentsController(paymentService: null!).Return(status, payment).Content!;

    [Fact]
    public void The_button_opens_the_app_on_the_bill_that_was_paid()
    {
        var id = Guid.NewGuid();

        var html = Page("paid", id);

        Assert.Contains($"href=\"aimpark://open/home/user/payments/{id}\"", html);
        Assert.Contains("Payment received", html);
    }

    [Fact]
    public void Without_a_bill_id_the_button_opens_the_payments_list()
    {
        var html = Page("cancelled", null);

        Assert.Contains("href=\"aimpark://open/home/user/payments\"", html);
        Assert.Contains("Payment cancelled", html);
    }
}
