<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('produk', function (Blueprint $table) {
            $table->id();
            $table->foreignId('kategori_id')->nullable()->constrained('kategori_produk')->nullOnDelete();
            $table->string('kode', 40)->unique();
            $table->string('nama');
            $table->text('deskripsi')->nullable();
            $table->string('satuan', 20);                       // pcs, dus, kg, dst.
            $table->decimal('harga', 15, 2);                    // harga dasar saat ini
            $table->unsignedInteger('stok_minimum')->default(0); // peringatan stok minimum
            $table->string('foto')->nullable();
            $table->boolean('is_active')->default(true);        // produk terpakai tidak dihapus, hanya dinonaktifkan
            $table->timestamps();
            $table->softDeletes();

            $table->index('nama');
        });

        // Harga khusus per toko / riwayat harga [TBC: tier harga]
        Schema::create('harga_produk', function (Blueprint $table) {
            $table->id();
            $table->foreignId('produk_id')->constrained('produk')->cascadeOnDelete();
            $table->foreignId('retailer_id')->nullable()->constrained('retailers')->cascadeOnDelete();
            $table->decimal('harga', 15, 2);
            $table->date('berlaku_mulai');
            $table->date('berlaku_sampai')->nullable();
            $table->timestamps();

            $table->index(['produk_id', 'retailer_id', 'berlaku_mulai']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('harga_produk');
        Schema::dropIfExists('produk');
    }
};
