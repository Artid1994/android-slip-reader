package com.example.slipreader

import android.graphics.Color
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.TextView
import androidx.recyclerview.widget.RecyclerView

class TransactionAdapter(private var list: List<TransactionRecord>) :
    RecyclerView.Adapter<TransactionAdapter.ViewHolder>() {

    class ViewHolder(view: View) : RecyclerView.ViewHolder(view) {
        val tvIcon: TextView = view.findViewById(R.id.tvCategoryIcon)
        val tvCategory: TextView = view.findViewById(R.id.tvCategoryName)
        val tvReceiverBank: TextView = view.findViewById(R.id.tvReceiverAndBank)
        val tvDateTime: TextView = view.findViewById(R.id.tvDateTime)
        val tvAmount: TextView = view.findViewById(R.id.tvAmount)
    }

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): ViewHolder {
        val view = LayoutInflater.from(parent.context)
            .inflate(R.layout.item_transaction_card, parent, false)
        return ViewHolder(view)
    }

    override fun onBindViewHolder(holder: ViewHolder, position: Int) {
        val item = list[position]

        // แมปไอคอนตามหมวดหมู่
        holder.tvIcon.text = when (item.category) {
            "อาหาร/เครื่องดื่ม" -> "🍔"
            "ช้อปปิ้ง/ของใช้" -> "🛒"
            "เดินทาง/น้ำมัน" -> "⛽"
            "รายรับทั่วไป" -> "💵"
            else -> if (item.type == TransactionType.INCOME) "💰" else "💸"
        }

        holder.tvCategory.text = item.category
        holder.tvReceiverBank.text = "${item.bankName} • ${item.receiverName}"
        holder.tvDateTime.text = "${item.dateStr}  ${item.timeStr}"

        // แสดงยอดเงินและสี (รายรับ=เขียว, รายจ่าย=แดง)
        if (item.type == TransactionType.INCOME) {
            holder.tvAmount.text = "+${item.amount} ฿"
            holder.tvAmount.setTextColor(Color.parseColor("#388E3C"))
        } else {
            holder.tvAmount.text = "-${item.amount} ฿"
            holder.tvAmount.setTextColor(Color.parseColor("#D32F2F"))
        }
    }

    override fun getItemCount(): Int = list.size

    fun updateData(newList: List<TransactionRecord>) {
        list = newList
        notifyDataSetChanged()
    }
}
