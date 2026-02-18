import DashboardLayout from "@/components/DashboardLayout";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Card } from "@/components/ui/card";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog";
import { trpc } from "@/lib/trpc";
import { Plus, DollarSign, Package, Users } from "lucide-react";
import { useState, useMemo } from "react";
import { toast } from "sonner";

export default function AdminOrders() {
  const [isCreateOrderOpen, setIsCreateOrderOpen] = useState(false);
  const [isUpdateDeliveryOpen, setIsUpdateDeliveryOpen] = useState(false);
  const [deliveryCost, setDeliveryCost] = useState("");

  const utils = trpc.useUtils();
  const { data: activeOrder } = trpc.groupOrders.getActive.useQuery();
  const { data: consolidated } = trpc.groupOrders.getConsolidated.useQuery(
    { groupOrderId: activeOrder?.id || 0 },
    { enabled: !!activeOrder }
  );

  const createOrderMutation = trpc.groupOrders.create.useMutation({
    onSuccess: () => {
      utils.groupOrders.getActive.invalidate();
      setIsCreateOrderOpen(false);
      setDeliveryCost("");
      toast.success("Pedido grupal creado exitosamente");
    },
    onError: (error) => {
      toast.error(error.message);
    },
  });

  const updateDeliveryMutation = trpc.groupOrders.updateDeliveryCost.useMutation({
    onSuccess: () => {
      utils.groupOrders.getActive.invalidate();
      utils.groupOrders.getConsolidated.invalidate();
      setIsUpdateDeliveryOpen(false);
      toast.success("Costo de domicilio actualizado");
    },
    onError: (error) => {
      toast.error(error.message);
    },
  });

  const closeOrderMutation = trpc.groupOrders.close.useMutation({
    onSuccess: () => {
      utils.groupOrders.getActive.invalidate();
      toast.success("Pedido cerrado exitosamente");
    },
    onError: (error) => {
      toast.error(error.message);
    },
  });

  const handleCreateOrder = (e: React.FormEvent) => {
    e.preventDefault();
    const costInCents = Math.round(parseFloat(deliveryCost || "0") * 100);
    createOrderMutation.mutate({ deliveryCost: costInCents });
  };

  const handleUpdateDelivery = (e: React.FormEvent) => {
    e.preventDefault();
    if (!activeOrder) return;
    const costInCents = Math.round(parseFloat(deliveryCost) * 100);
    updateDeliveryMutation.mutate({
      id: activeOrder.id,
      deliveryCost: costInCents,
    });
  };

  const handleCloseOrder = () => {
    if (!activeOrder) return;
    if (confirm("¿Cerrar el pedido grupal actual? Los usuarios no podrán modificar sus pedidos.")) {
      closeOrderMutation.mutate({ id: activeOrder.id });
    }
  };

  const itemsByUser = useMemo(() => {
    if (!consolidated?.items) return [];

    const userMap = new Map<number, { userId: number; userName: string | null; items: any[]; total: number }>();
    const usersMap = new Map((consolidated.users || []).map(u => [u.id, u]));

    for (const item of consolidated.items) {
      const existing = userMap.get(item.userId);
      const product = consolidated.productTotals.find((pt) => pt.product.id === item.productId);
      const itemTotal = product ? product.product.price * item.quantity : 0;
      const user = usersMap.get(item.userId);

      if (existing) {
        existing.items.push({ ...item, product: product?.product });
        existing.total += itemTotal;
      } else {
        userMap.set(item.userId, {
          userId: item.userId,
          userName: user?.name || null,
          items: [{ ...item, product: product?.product }],
          total: itemTotal,
        });
      }
    }

    return Array.from(userMap.values());
  }, [consolidated]);

  const grandTotal = useMemo(() => {
    if (!consolidated?.productTotals) return 0;
    return consolidated.productTotals.reduce((sum, pt) => sum + pt.totalPrice, 0);
  }, [consolidated]);

  const participantCount = itemsByUser.length;
  const deliveryPerPerson =
    participantCount > 0 ? Math.ceil((activeOrder?.deliveryCost || 0) / participantCount) : 0;
    
  return (
    <DashboardLayout>
      <div className="p-8 max-w-7xl mx-auto">
        {/* Header */}
        <div className="mb-8">
          <h1 className="text-4xl font-bold mb-2">Consolidado</h1>
          <p className="text-muted-foreground">Vista general del pedido grupal</p>
        </div>

        {!activeOrder ? (
          <Card className="p-12 text-center shadow-sm">
            <p className="text-xl font-medium mb-6">No hay pedido activo</p>
            <Dialog open={isCreateOrderOpen} onOpenChange={setIsCreateOrderOpen}>
              <DialogTrigger asChild>
                <Button size="lg" className="shadow-sm">
                  <Plus className="w-5 h-5 mr-2" />
                  Crear Pedido Grupal
                </Button>
              </DialogTrigger>
              <DialogContent>
                <DialogHeader>
                  <DialogTitle>Nuevo Pedido Grupal</DialogTitle>
                </DialogHeader>
                <form onSubmit={handleCreateOrder} className="space-y-4">
                  <div>
                    <Label className="mb-2 block">Costo de Domicilio (COP) - Opcional</Label>
                    <Input
                      type="number"
                      step="0.01"
                      value={deliveryCost}
                      onChange={(e) => setDeliveryCost(e.target.value)}
                      placeholder="Ej: 5000"
                    />
                    <p className="text-sm text-muted-foreground mt-2">
                      Se dividirá equitativamente entre todos los participantes
                    </p>
                  </div>
                  <Button
                    type="submit"
                    className="w-full"
                    disabled={createOrderMutation.isPending}
                  >
                    Crear
                  </Button>
                </form>
              </DialogContent>
            </Dialog>
          </Card>
        ) : (
          <>
            {/* Información del pedido activo */}
            <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
              <Card className="p-6 shadow-sm">
                <div className="flex items-center gap-3 mb-3">
                  <div className="p-2 bg-primary/10 rounded-lg">
                    <DollarSign className="w-6 h-6 text-primary" />
                  </div>
                  <h3 className="font-semibold">Domicilio</h3>
                </div>
                <p className="text-3xl font-bold mb-4">
                  ${((activeOrder.deliveryCost || 0) / 100).toLocaleString("es-CO")}
                </p>
                <Dialog open={isUpdateDeliveryOpen} onOpenChange={setIsUpdateDeliveryOpen}>
                  <DialogTrigger asChild>
                    <Button
                      variant="outline"
                      size="sm"
                      onClick={() =>
                        setDeliveryCost(((activeOrder.deliveryCost || 0) / 100).toFixed(2))
                      }
                    >
                      Actualizar
                    </Button>
                  </DialogTrigger>
                  <DialogContent>
                    <DialogHeader>
                      <DialogTitle>Actualizar Domicilio</DialogTitle>
                    </DialogHeader>
                    <form onSubmit={handleUpdateDelivery} className="space-y-4">
                      <div>
                        <Label className="mb-2 block">Costo de Domicilio (COP)</Label>
                        <Input
                          type="number"
                          step="0.01"
                          value={deliveryCost}
                          onChange={(e) => setDeliveryCost(e.target.value)}
                          required
                        />
                      </div>
                      <Button
                        type="submit"
                        className="w-full"
                        disabled={updateDeliveryMutation.isPending}
                      >
                        Actualizar
                      </Button>
                    </form>
                  </DialogContent>
                </Dialog>
              </Card>

              <Card className="p-6 shadow-sm">
                <div className="flex items-center gap-3 mb-3">
                  <div className="p-2 bg-primary/10 rounded-lg">
                    <Users className="w-6 h-6 text-primary" />
                  </div>
                  <h3 className="font-semibold">Participantes</h3>
                </div>
                <p className="text-3xl font-bold mb-2">{participantCount}</p>
                <p className="text-sm text-muted-foreground">
                  Domicilio por persona: ${(deliveryPerPerson / 100).toLocaleString("es-CO")}
                </p>
              </Card>

              <Card className="p-6 shadow-sm">
                <div className="flex items-center gap-3 mb-3">
                  <div className="p-2 bg-primary/10 rounded-lg">
                    <Package className="w-6 h-6 text-primary" />
                  </div>
                  <h3 className="font-semibold">Total General</h3>
                </div>
                <p className="text-3xl font-bold mb-4">
                  ${((grandTotal + (activeOrder.deliveryCost || 0)) / 100).toLocaleString("es-CO")}
                </p>
                <Button
                  variant="destructive"
                  size="sm"
                  onClick={handleCloseOrder}
                  disabled={closeOrderMutation.isPending}
                >
                  Cerrar Pedido
                </Button>
              </Card>
            </div>

            {/* Resumen por producto */}
            {consolidated?.productTotals && consolidated.productTotals.length > 0 && (
              <div className="mb-8">
                <h2 className="text-2xl font-semibold mb-4">Resumen por Producto</h2>
                <Card className="shadow-sm overflow-hidden">
                  <div className="overflow-x-auto">
                    <table className="w-full">
                      <thead className="bg-muted/50">
                        <tr>
                          <th className="text-left p-4 font-semibold">Producto</th>
                          <th className="text-center p-4 font-semibold">Cantidad Total</th>
                          <th className="text-right p-4 font-semibold">Subtotal</th>
                        </tr>
                      </thead>
                      <tbody>
                        {consolidated.productTotals.map((pt, index) => (
                          <tr
                            key={pt.product.id}
                            className={index % 2 === 0 ? "bg-background" : "bg-muted/20"}
                          >
                            <td className="p-4">{pt.product.name}</td>
                            <td className="p-4 text-center font-medium">{pt.totalQuantity}</td>
                            <td className="p-4 text-right font-medium">
                              ${(pt.totalPrice / 100).toLocaleString("es-CO")}
                            </td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  </div>
                </Card>
              </div>
            )}

            {/* Pedidos por usuario */}
            {itemsByUser.length > 0 && (
              <div>
                <h2 className="text-2xl font-semibold mb-4">Pedidos por Usuario</h2>
                <div className="space-y-4">
                  {itemsByUser.map((userOrder) => (
                    <Card key={userOrder.userId} className="p-6 shadow-sm">
                      <div className="flex justify-between items-start mb-4">
                        <div>
                          <h3 className="text-xl font-semibold">
                            {userOrder.userName || `Usuario #${userOrder.userId}`}
                          </h3>
                        </div>
                        <div className="text-right">
                          <p className="text-sm text-muted-foreground mb-1">Total a pagar</p>
                          <p className="text-2xl font-bold text-primary">
                            ${((userOrder.total + deliveryPerPerson) / 100).toLocaleString("es-CO")}
                          </p>
                          <p className="text-sm text-muted-foreground mt-1">
                            Productos: ${(userOrder.total / 100).toLocaleString("es-CO")} +
                            Domicilio: ${(deliveryPerPerson / 100).toLocaleString("es-CO")}
                          </p>
                        </div>
                      </div>
                      <div className="border-t pt-4">
                        <table className="w-full">
                          <thead>
                            <tr className="border-b">
                              <th className="text-left pb-2 font-semibold text-sm">Producto</th>
                              <th className="text-center pb-2 font-semibold text-sm">Cantidad</th>
                              <th className="text-right pb-2 font-semibold text-sm">Subtotal</th>
                            </tr>
                          </thead>
                          <tbody>
                            {userOrder.items.map((item) => (
                              <tr key={item.id} className="border-b last:border-0">
                                <td className="py-2">{item.product?.name}</td>
                                <td className="py-2 text-center font-medium">{item.quantity}</td>
                                <td className="py-2 text-right font-medium">
                                  $
                                  {(
                                    ((item.product?.price || 0) * item.quantity) /
                                    100
                                  ).toLocaleString("es-CO")}
                                </td>
                              </tr>
                            ))}
                          </tbody>
                        </table>
                      </div>
                    </Card>
                  ))}
                </div>
              </div>
            )}
          </>
        )}
      </div>
    </DashboardLayout>
  );
}
