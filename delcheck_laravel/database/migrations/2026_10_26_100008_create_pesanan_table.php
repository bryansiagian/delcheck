<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('pesanan', function (Blueprint $table) {
            $table->id();
            $table->string('nomor', 40)->unique();
            $table->foreignId('retailer_id')->constrained('retailers');
            $table->foreignId('sales_id')->nullable()->constrained('users')->nullOnDelete(); // sales terkait/pengonfirmasi
            $table->string('sumber', 10);                    // retail | sales
            $table->foreignId('dibuat_oleh')->constrained('users');

            // diajukan, menunggu_konfirmasi_sales, dikonfirmasi, ditolak,
            // diproses, dikirim, diterima, selesai, dibatalkan
            $table->string('status', 30)->default('menunggu_konfirmasi_sales');
            $table->decimal('total', 15, 2)->default(0);
            $table->text('catatan')->nullable();

            $table->foreignId('dikonfirmasi_oleh')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamp('dikonfirmasi_at')->nullable();
            $table->text('alasan_ditolak')->nullable();      // BR-06

            $table->foreignId('diproses_oleh')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamp('diproses_at')->nullable();

            $table->timestamp('dikirim_at')->nullable();

            $table->foreignId('diterima_oleh')->nullable()->constrained('users')->nullOnDelete(); // Retail (BR-10)
            $table->timestamp('diterima_at')->nullable();

            $table->timestamp('selesai_at')->nullable();
            $table->foreignId('dibatalkan_oleh')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamp('dibatalkan_at')->nullable();
            $table->text('alasan_batal')->nullable();        // BR-06

            $table->timestamps();

            $table->index(['status', 'created_at']);
            $table->index(['retailer_id', 'status']);
            $table->index(['sales_id', 'status']);
        });

        Schema::create('item_pesanan', function (Blueprint $table) {
            $table->id();
            $table->foreignId('pesanan_id')->constrained('pesanan')->cascadeOnDelete();
            $table->foreignId('produk_id')->constrained('produk');
            $table->string('nama_produk');                   // snapshot saat pesan
            $table->string('satuan', 20);
            $table->decimal('harga', 15, 2);                 // snapshot harga
            $table->unsignedInteger('qty');
            $table->decimal('subtotal', 15, 2);
            $table->timestamps();

            $table->index('pesanan_id');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('item_pesanan');
        Schema::dropIfExists('pesanan');
    }
};
