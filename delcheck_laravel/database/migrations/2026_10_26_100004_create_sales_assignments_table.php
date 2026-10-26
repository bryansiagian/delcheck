<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('sales_assignments', function (Blueprint $table) {
            $table->id();
            $table->foreignId('sales_id')->constrained('users')->cascadeOnDelete();
            $table->foreignId('retailer_id')->constrained('retailers')->cascadeOnDelete();
            $table->foreignId('ditugaskan_oleh')->nullable()->constrained('users')->nullOnDelete();
            $table->date('mulai')->nullable();
            $table->date('selesai')->nullable();
            $table->boolean('is_active')->default(true);
            $table->timestamps();

            $table->unique(['sales_id', 'retailer_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('sales_assignments');
    }
};
