<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('ulasan', function (Blueprint $table) {
            $table->id();
            $table->foreignId('retailer_id')->constrained('retailers')->cascadeOnDelete();
            $table->foreignId('user_id')->constrained('users');
            $table->foreignId('pesanan_id')->nullable()->constrained('pesanan')->nullOnDelete(); // [TBC: terkait pesanan?]
            $table->unsignedTinyInteger('rating');                     // 1-5
            $table->text('komentar')->nullable();
            $table->timestamps();

            $table->index(['rating', 'created_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('ulasan');
    }
};
