import DashboardLayout from "@/components/DashboardLayout";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Card } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { trpc } from "@/lib/trpc";
import { Plus, Minus, Trash2, ShoppingBag } from "lucide-react";
import { useState, useMemo } from "react";
import { toast } from "sonner";

export default function Home() {
  const [quantities, setQuantities] = useState<Record<number, number>>({});

  const utils = trpc.useUtils();
  const { data: products, isLoading: productsLoading } = trpc.products.list.useQuery();
  const { data: activeOrder } = trpc.groupOrders.getActive.useQuery();
  const { data: myItems } = trpc.orderItems.myItems.useQuery(
    { groupOrderId: activeOrder?.id || 0 },
    { enabled: !!activeOrder }
  );
  const { data: myTotal } = trpc.orderItems.calculateMyTotal.useQuery(
    { groupOrderId: activeOrder?.id || 0 },
    { enabled: !!activeOrder }
  );

  const addItemMutation = trpc.orderItems.add.useMutation({
    onSuccess: () => {
      utils.orderItems.myItems.invalidate();
      utils.orderItems.calculateMyTotal.invalidate();
      toast.success("Producto agregado a tu pedido");
    },
    onError: (error) => {
      toast.error(error.message);
    },
  });

  const updateItemMutation = trpc.orderItems.update.useMutation({
    onSuccess: () => {
      utils.orderItems.myItems.invalidate();
      utils.orderItems.calculateMyTotal.invalidate();
      toast.success("Cantidad actualizada");
    },
    onError: (error) => {
      toast.error(error.message);
    },
  });

  const deleteItemMutation = trpc.orderItems.delete.useMutation({
    onSuccess: () => {
      utils.orderItems.myItems.invalidate();
      utils.orderItems.calculateMyTotal.invalidate();
      toast.success("Producto eliminado de tu pedido");
    },
    onError: (error) => {
      toast.error(error.message);
    },
  });

  const handleAddToOrder = (productId: number) => {
    const quantity = quantities[productId] || 1;
    if (!activeOrder) {
      toast.error("No hay un pedido grupal activo");
      return;
    }

    addItemMutation.mutate({
      groupOrderId: activeOrder.id,
      productId,
      quantity,
    });
    setQuantities({ ...quantities, [productId]: 1 });
  };

  const handleUpdateQuantity = (itemId: number, newQuantity: number) => {
    if (newQuantity < 1) return;
    updateItemMutation.mutate({ id: itemId, quantity: newQuantity });
  };

  const handleDeleteItem = (itemId: number) => {
    deleteItemMutation.mutate({ id: itemId });
  };

  const myItemsWithProducts = useMemo(() => {
    if (!myItems || !products) return [];
    return myItems.map((item) => ({
      ...item,
      product: products.find((p) => p.id === item.productId),
    }));
  }, [myItems, products]);

  return (
    <DashboardLayout>
      <div className="p-4 sm:p-8 max-w-7xl mx-auto">
        {/* Header */}
        <div className="mb-8">
          <h1 className="text-3xl sm:text-4xl font-bold mb-2">Mi Pedido</h1>
          <p className="text-muted-foreground">Selecciona productos del catálogo</p>
        </div>

        {!activeOrder ? (
          <Card className="p-12 text-center shadow-sm">
            <p className="text-xl font-medium mb-2">No hay pedido activo</p>
            <p className="text-muted-foreground">
              El administrador debe crear un pedido grupal primero
            </p>
          </Card>
        ) : (
          <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
            {/* Catálogo de productos */}
            <div className="lg:col-span-2 space-y-6">
              <h2 className="text-2xl font-semibold">Catálogo</h2>

              {productsLoading ? (
                <div className="text-center py-12">
                  <p className="text-muted-foreground">Cargando productos...</p>
                </div>
              ) : products && products.length > 0 ? (
                <div className="space-y-4">
                  {products.map((product) => (
                    <Card
                      key={product.id}
                      className="p-4 sm:p-6 shadow-sm hover:shadow-md transition-shadow"
                    >
                      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
                        <div className="flex-1">
                          <h3 className="text-lg sm:text-xl font-semibold mb-1">{product.name}</h3>
                          <p className="text-base sm:text-lg text-muted-foreground">
                            ${(product.price / 100).toLocaleString("es-CO")}
                          </p>
                        </div>
                        <div className="flex flex-col sm:flex-row items-stretch sm:items-center gap-3">
                          <div className="flex items-center gap-2 justify-center sm:justify-start">
                            <Button
                              variant="outline"
                              size="icon"
                              onClick={() =>
                                setQuantities({
                                  ...quantities,
                                  [product.id]: Math.max(1, (quantities[product.id] || 1) - 1),
                                })
                              }
                            >
                              <Minus className="w-4 h-4" />
                            </Button>
                            <Input
                              type="number"
                              min="1"
                              value={quantities[product.id] || 1}
                              onChange={(e) =>
                                setQuantities({
                                  ...quantities,
                                  [product.id]: Math.max(1, parseInt(e.target.value) || 1),
                                })
                              }
                              className="w-20 text-center"
                            />
                            <Button
                              variant="outline"
                              size="icon"
                              onClick={() =>
                                setQuantities({
                                  ...quantities,
                                  [product.id]: (quantities[product.id] || 1) + 1,
                                })
                              }
                            >
                              <Plus className="w-4 h-4" />
                            </Button>
                          </div>
                          <Button
                            onClick={() => handleAddToOrder(product.id)}
                            disabled={addItemMutation.isPending}
                            className="w-full sm:w-auto"
                          >
                            <Plus className="w-4 h-4 mr-2" />
                            Agregar
                          </Button>
                        </div>
                      </div>
                    </Card>
                  ))}
                </div>
              ) : (
                <Card className="p-12 text-center shadow-sm">
                  <p className="text-xl font-medium">No hay productos disponibles</p>
                </Card>
              )}
            </div>

            {/* Resumen del pedido */}
            <div className="lg:col-span-1">
              <Card className="p-4 sm:p-6 shadow-lg lg:sticky lg:top-8">
                <div className="flex items-center gap-2 mb-6">
                  <ShoppingBag className="w-6 h-6 text-primary" />
                  <h2 className="text-2xl font-semibold">Resumen</h2>
                </div>

                {myItemsWithProducts.length === 0 ? (
                  <p className="text-center text-muted-foreground py-8">
                    Aún no has agregado productos
                  </p>
                ) : (
                  <>
                    <div className="space-y-4 mb-6 pb-6 border-b">
                      {myItemsWithProducts.map((item) => (
                        <div key={item.id} className="flex flex-col sm:flex-row sm:items-start sm:justify-between gap-3">
                          <div className="flex-1 min-w-0">
                            <p className="font-medium truncate">{item.product?.name}</p>
                            <p className="text-sm text-muted-foreground">
                              {item.quantity} × $
                              {((item.product?.price || 0) / 100).toLocaleString("es-CO")}
                            </p>
                          </div>
                          <div className="flex items-center gap-2 flex-shrink-0">
                            <div className="flex items-center border rounded-md">
                              <button
                                className="px-2 py-1 hover:bg-secondary min-w-[32px]"
                                onClick={() => handleUpdateQuantity(item.id, item.quantity - 1)}
                                disabled={item.quantity <= 1}
                              >
                                -
                              </button>
                              <span className="px-3 py-1 font-medium border-x min-w-[40px] text-center">
                                {item.quantity}
                              </span>
                              <button
                                className="px-2 py-1 hover:bg-secondary min-w-[32px]"
                                onClick={() => handleUpdateQuantity(item.id, item.quantity + 1)}
                              >
                                +
                              </button>
                            </div>
                            <Button
                              variant="ghost"
                              size="icon"
                              onClick={() => handleDeleteItem(item.id)}
                              className="flex-shrink-0"
                            >
                              <Trash2 className="w-4 h-4 text-destructive" />
                            </Button>
                          </div>
                        </div>
                      ))}
                    </div>

                    {myTotal && (
                      <div className="space-y-3">
                        <div className="flex justify-between items-center">
                          <span className="text-muted-foreground">Productos:</span>
                          <span className="font-medium">
                            ${(myTotal.productsTotal / 100).toLocaleString("es-CO")}
                          </span>
                        </div>
                        <div className="flex justify-between items-center">
                          <span className="text-muted-foreground">
                            Domicilio ({myTotal.participantCount} personas):
                          </span>
                          <span className="font-medium">
                            ${(myTotal.deliveryShare / 100).toLocaleString("es-CO")}
                          </span>
                        </div>
                        <div className="border-t pt-3 mt-3">
                          <div className="flex justify-between items-center">
                            <span className="text-lg font-semibold">Total:</span>
                            <span className="text-2xl font-bold text-primary">
                              ${(myTotal.grandTotal / 100).toLocaleString("es-CO")}
                            </span>
                          </div>
                        </div>
                      </div>
                    )}
                  </>
                )}
              </Card>
            </div>
          </div>
        )}
      </div>
    </DashboardLayout>
  );
}
