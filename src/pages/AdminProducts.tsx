import DashboardLayout from "@/components/DashboardLayout";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog";
import { Card } from "@/components/ui/card";
import { trpc } from "@/lib/trpc";
import { Plus, Pencil, Trash2 } from "lucide-react";
import { useState } from "react";
import { toast } from "sonner";

export default function AdminProducts() {
  const [isCreateOpen, setIsCreateOpen] = useState(false);
  const [editingProduct, setEditingProduct] = useState<any>(null);
  const [formData, setFormData] = useState({ name: "", price: "" });

  const utils = trpc.useUtils();
  const { data: products, isLoading } = trpc.products.list.useQuery();

  const createMutation = trpc.products.create.useMutation({
    onSuccess: () => {
      utils.products.list.invalidate();
      setIsCreateOpen(false);
      setFormData({ name: "", price: "" });
      toast.success("Producto creado exitosamente");
    },
    onError: (error) => {
      toast.error(error.message);
    },
  });

  const updateMutation = trpc.products.update.useMutation({
    onSuccess: () => {
      utils.products.list.invalidate();
      setEditingProduct(null);
      setFormData({ name: "", price: "" });
      toast.success("Producto actualizado exitosamente");
    },
    onError: (error) => {
      toast.error(error.message);
    },
  });

  const deleteMutation = trpc.products.delete.useMutation({
    onSuccess: () => {
      utils.products.list.invalidate();
      toast.success("Producto eliminado exitosamente");
    },
    onError: (error) => {
      toast.error(error.message);
    },
  });

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    const priceInCents = Math.round(parseFloat(formData.price) * 100);

    if (editingProduct) {
      updateMutation.mutate({
        id: editingProduct.id,
        name: formData.name,
        price: priceInCents,
      });
    } else {
      createMutation.mutate({
        name: formData.name,
        price: priceInCents,
      });
    }
  };

  const openEditDialog = (product: any) => {
    setEditingProduct(product);
    setFormData({
      name: product.name,
      price: (product.price / 100).toFixed(2),
    });
  };

  return (
    <DashboardLayout>
      <div className="p-8 max-w-7xl mx-auto">
        {/* Header */}
        <div className="mb-8">
          <h1 className="text-4xl font-bold mb-2">Productos</h1>
          <p className="text-muted-foreground">Gestiona el catálogo de productos disponibles</p>
        </div>

        {/* Botón crear */}
        <div className="mb-6">
          <Dialog open={isCreateOpen} onOpenChange={setIsCreateOpen}>
            <DialogTrigger asChild>
              <Button
                size="lg"
                className="shadow-sm"
                onClick={() => {
                  setEditingProduct(null);
                  setFormData({ name: "", price: "" });
                }}
              >
                <Plus className="w-5 h-5 mr-2" />
                Agregar Producto
              </Button>
            </DialogTrigger>
            <DialogContent>
              <DialogHeader>
                <DialogTitle>
                  {editingProduct ? "Editar Producto" : "Nuevo Producto"}
                </DialogTitle>
              </DialogHeader>
              <form onSubmit={handleSubmit} className="space-y-4">
                <div>
                  <Label className="mb-2 block">Nombre</Label>
                  <Input
                    value={formData.name}
                    onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                    required
                    placeholder="Ej: Hamburguesa"
                  />
                </div>
                <div>
                  <Label className="mb-2 block">Precio (COP)</Label>
                  <Input
                    type="number"
                    step="0.01"
                    value={formData.price}
                    onChange={(e) => setFormData({ ...formData, price: e.target.value })}
                    required
                    placeholder="Ej: 15000"
                  />
                </div>
                <Button
                  type="submit"
                  className="w-full"
                  disabled={createMutation.isPending || updateMutation.isPending}
                >
                  {editingProduct ? "Actualizar" : "Crear"}
                </Button>
              </form>
            </DialogContent>
          </Dialog>
        </div>

        {/* Lista de productos */}
        {isLoading ? (
          <div className="text-center py-12">
            <p className="text-muted-foreground">Cargando productos...</p>
          </div>
        ) : products && products.length > 0 ? (
          <div className="grid gap-4">
            {products.map((product) => (
              <Card key={product.id} className="p-6 shadow-sm hover:shadow-md transition-shadow">
                <div className="flex items-center justify-between">
                  <div className="flex-1">
                    <h3 className="text-xl font-semibold mb-1">{product.name}</h3>
                    <p className="text-lg text-muted-foreground">
                      ${(product.price / 100).toLocaleString("es-CO")}
                    </p>
                  </div>
                  <div className="flex gap-2">
                    <Dialog
                      open={editingProduct?.id === product.id}
                      onOpenChange={(open) => {
                        if (!open) setEditingProduct(null);
                      }}
                    >
                      <DialogTrigger asChild>
                        <Button
                          variant="outline"
                          size="sm"
                          onClick={() => openEditDialog(product)}
                        >
                          <Pencil className="w-4 h-4" />
                        </Button>
                      </DialogTrigger>
                      <DialogContent>
                        <DialogHeader>
                          <DialogTitle>Editar Producto</DialogTitle>
                        </DialogHeader>
                        <form onSubmit={handleSubmit} className="space-y-4">
                          <div>
                            <Label className="mb-2 block">Nombre</Label>
                            <Input
                              value={formData.name}
                              onChange={(e) =>
                                setFormData({ ...formData, name: e.target.value })
                              }
                              required
                            />
                          </div>
                          <div>
                            <Label className="mb-2 block">Precio (COP)</Label>
                            <Input
                              type="number"
                              step="0.01"
                              value={formData.price}
                              onChange={(e) =>
                                setFormData({ ...formData, price: e.target.value })
                              }
                              required
                            />
                          </div>
                          <Button
                            type="submit"
                            className="w-full"
                            disabled={updateMutation.isPending}
                          >
                            Actualizar
                          </Button>
                        </form>
                      </DialogContent>
                    </Dialog>
                    <Button
                      variant="outline"
                      size="sm"
                      onClick={() => {
                        if (confirm(`¿Eliminar "${product.name}"?`)) {
                          deleteMutation.mutate({ id: product.id });
                        }
                      }}
                      disabled={deleteMutation.isPending}
                    >
                      <Trash2 className="w-4 h-4 text-destructive" />
                    </Button>
                  </div>
                </div>
              </Card>
            ))}
          </div>
        ) : (
          <Card className="p-12 text-center shadow-sm">
            <p className="text-xl font-medium mb-2">No hay productos</p>
            <p className="text-muted-foreground">Agrega el primer producto al catálogo</p>
          </Card>
        )}
      </div>
    </DashboardLayout>
  );
}
