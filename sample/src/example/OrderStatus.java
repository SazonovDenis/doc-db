package example;

/**
 * Статус заказа: значения orders.status.
 */
public final class OrderStatus {

    /** Новый: создан, не оплачен */
    public static final int NEW = 1;

    /** Оплачен: оплата получена, ждёт отгрузки */
    public static final int PAID = 2;

    /** Отгружен: передан в доставку */
    public static final int SHIPPED = 3;

    // Отменён: отменён покупателем или магазином
    public static final int CANCELLED = 4;

    private OrderStatus() {
    }

}
