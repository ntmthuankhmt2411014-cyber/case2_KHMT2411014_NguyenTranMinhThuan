const mongoose = require('mongoose');

const taskSchema = new mongoose.Schema(
  {
    title: { type: String, required: true },

    description: { type: String, default: '' },

    category: { type: String, default: 'Other' },

    priority: {
      type: String,
      enum: ['Low', 'Medium', 'High'],
      default: 'Medium',
    },

    status: {
      type: String,
      enum: ['Pending', 'InProgress', 'Completed'],
      default: 'Pending',
    },
    
    dueDate: { type: Date },
  },
  { timestamps: true }
);

module.exports = mongoose.model('Task', taskSchema);