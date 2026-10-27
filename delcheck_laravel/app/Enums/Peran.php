<?php

namespace App\Enums;

enum Peran: string
{
    case Retail = 'retail';
    case Sales = 'sales';
    case Admin = 'admin';
    case Warehouse = 'warehouse';

    public function label(): string
    {
        return match ($this) {
            self::Retail => 'Toko / Retail',
            self::Sales => 'Sales',
            self::Admin => 'Admin (Distributor)',
            self::Warehouse => 'Warehouse',
        };
    }
}
